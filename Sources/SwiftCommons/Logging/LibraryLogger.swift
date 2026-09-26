import Foundation
import os

/// A level-gated OSLog front end for library packages, whose verbosity the library's users
/// control.
///
/// A library creates one `LibraryLogger` for its subsystem, exposes ``setLevel(_:)`` (or
/// ``level``) through its own configuration, and logs through per-category handles:
///
///     // Inside the library
///     let log = LibraryLogger(subsystem: "MyNetworking")
///     let networkLog = log.category("network")
///
///     networkLog.debug("Sending request id=\(requestID)")
///     networkLog.debug("Resolved endpoint", url: url)  // URL logged privately
///     networkLog.error("Request failed id=\(requestID)", error: error)
///
///     // In the app using the library
///     MyNetworking.log.setLevel(.debug)
///
/// Messages below the current level are skipped before their text is built. Each instance owns
/// its level, so two libraries using `LibraryLogger` don't share one process-wide setting. The
/// level defaults to ``Level/warning``.
///
/// **Privacy:** messages are logged **public**, so keep them to identifiers and non-sensitive
/// state. Pass anything user-derived through the `error:` or `url:` parameters, which are
/// logged privately. For errors, the type, domain, and code are public and the
/// `localizedDescription` is private, matching `Logger.error(_:error:context:)`.
public final class LibraryLogger: Sendable {
    /// How much a ``LibraryLogger`` emits, from nothing (``off``) to everything (``debug``).
    ///
    /// Setting a level enables it and every more severe level.
    public enum Level: Int, Sendable, Comparable, CaseIterable {
        /// Emit nothing.
        case off = 0
        /// Emit errors only.
        case error = 1
        /// Emit warnings and errors.
        case warning = 2
        /// Emit informational messages, warnings, and errors.
        case info = 3
        /// Emit everything, including debug diagnostics.
        case debug = 4

        /// Orders levels from least to most verbose, so `level >= .info` means "at least info".
        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// A logger for one category of a ``LibraryLogger``'s subsystem, gated by that logger's
    /// level.
    ///
    /// Create one per category with ``LibraryLogger/category(_:)`` and keep it; it's cheap to
    /// copy and safe to share across threads.
    public struct Category: Sendable {
        /// The category name shown in Console and `log` output.
        public let name: String

        private let owner: LibraryLogger
        private let osLogger: Logger

        fileprivate init(name: String, owner: LibraryLogger) {
            self.name = name
            self.owner = owner
            self.osLogger = Logger(subsystem: owner.subsystem, category: name)
        }

        /// Logs a public debug message when the level is ``Level/debug``.
        /// - Parameter message: Non-sensitive text; only built when the message is emitted.
        public func debug(_ message: @autoclosure () -> String) {
            guard shouldEmit(.debug) else { return }
            let text = message()
            osLogger.debug("\(text, privacy: .public)")
        }

        /// Logs a public debug message followed by a privately logged URL, when the level is
        /// ``Level/debug``.
        ///
        /// Query strings and paths often carry tokens or user identifiers, so the URL is
        /// redacted in logs unless private data is enabled.
        /// - Parameters:
        ///   - message: Non-sensitive text; only built when the message is emitted.
        ///   - url: The URL to log privately.
        public func debug(_ message: @autoclosure () -> String, url: URL) {
            guard shouldEmit(.debug) else { return }
            let text = message()
            osLogger.debug("\(text, privacy: .public) \(url.absoluteString, privacy: .private)")
        }

        /// Logs a public info message when the level is ``Level/info`` or more verbose.
        /// - Parameter message: Non-sensitive text; only built when the message is emitted.
        public func info(_ message: @autoclosure () -> String) {
            guard shouldEmit(.info) else { return }
            let text = message()
            osLogger.info("\(text, privacy: .public)")
        }

        /// Logs a public warning when the level is ``Level/warning`` or more verbose.
        /// - Parameter message: Non-sensitive text; only built when the message is emitted.
        public func warning(_ message: @autoclosure () -> String) {
            guard shouldEmit(.warning) else { return }
            let text = message()
            osLogger.warning("\(text, privacy: .public)")
        }

        /// Logs a public error message, plus an optional error, when the level is not
        /// ``Level/off``.
        ///
        /// The error's type, domain, and code are logged public; its `localizedDescription` is
        /// private.
        /// - Parameters:
        ///   - message: Non-sensitive text; only built when the message is emitted.
        ///   - error: The underlying error, if any.
        public func error(_ message: @autoclosure () -> String, error: (any Error)? = nil) {
            guard shouldEmit(.error) else { return }
            let text = message()
            guard let error else {
                osLogger.error("\(text, privacy: .public)")
                return
            }
            let summary = ErrorLogSummary(error)
            osLogger.error(
                """
                \(text, privacy: .public) | Error: \(summary.identity, privacy: .public) \
                (\(summary.localizedDescription, privacy: .private))
                """
            )
        }

        private func shouldEmit(_ level: Level) -> Bool {
            guard owner.isEnabled(level) else { return false }
            owner.emissionObserver?(level, name)
            return true
        }
    }

    /// The OSLog subsystem every category logs under.
    public let subsystem: String

    private let threshold: OSAllocatedUnfairLock<Level>

    /// Called with the level and category of every message that passes the level gate. Tests
    /// only; OSLog output can't be read back.
    let emissionObserver: (@Sendable (Level, String) -> Void)?

    /// Creates a logger for `subsystem`.
    ///
    /// - Parameters:
    ///   - subsystem: The OSLog subsystem, usually the library's name or bundle identifier.
    ///   - defaultLevel: The level until ``setLevel(_:)`` changes it. Defaults to
    ///     ``Level/warning``.
    public convenience init(subsystem: String, defaultLevel: Level = .warning) {
        self.init(subsystem: subsystem, defaultLevel: defaultLevel, emissionObserver: nil)
    }

    init(
        subsystem: String,
        defaultLevel: Level,
        emissionObserver: (@Sendable (Level, String) -> Void)?
    ) {
        self.subsystem = subsystem
        self.threshold = OSAllocatedUnfairLock(initialState: defaultLevel)
        self.emissionObserver = emissionObserver
    }

    /// The current level. Messages less severe than this are skipped.
    public var level: Level {
        threshold.withLock { $0 }
    }

    /// Changes the level for every category of this logger. Safe to call from any thread.
    ///
    /// - Parameter newLevel: The new level.
    public func setLevel(_ newLevel: Level) {
        threshold.withLock { $0 = newLevel }
    }

    /// Whether a message at `messageLevel` would currently be emitted.
    ///
    /// Use it to skip expensive diagnostics work that isn't just building the message string
    /// (which the logging methods already defer).
    ///
    /// - Parameter messageLevel: The severity of the message. ``Level/off`` is never enabled.
    /// - Returns: `true` if the message would be logged.
    public func isEnabled(_ messageLevel: Level) -> Bool {
        messageLevel != .off && messageLevel <= level
    }

    /// Returns a logger for one category of this subsystem, gated by this logger's level.
    ///
    /// - Parameter name: The category name, e.g. `"network"` or `"cache"`.
    /// - Returns: A category logger. Create it once and reuse it.
    public func category(_ name: String) -> Category {
        Category(name: name, owner: self)
    }
}
