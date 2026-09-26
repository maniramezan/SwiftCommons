import Foundation
import OSLog

// MARK: - Logger Extension with Helper Methods

extension Logger {

    // MARK: Automatic Category Creation

    /// Creates a logger whose category is the name of `type`.
    /// - Parameters:
    ///   - subsystem: The subsystem identifier (usually package name)
    ///   - type: The type whose name becomes the category.
    ///   - file: Unused; retained for source compatibility.
    /// - Returns: Configured Logger instance
    ///
    /// Usage:
    /// ```swift
    /// private let logger = Logger.forType(subsystem: "SwiftUICalendar", CalendarViewModel.self)
    /// // Category is "CalendarViewModel"
    /// ```
    public static func forType(
        subsystem: String,
        _ type: Any.Type,
        file: String = #file
    ) -> Logger {
        let category = String(describing: type)
        return Logger(subsystem: subsystem, category: category)
    }

    /// Creates a logger with automatic category from the calling file
    /// Infers the type from the file path
    /// - Parameters:
    ///   - subsystem: The subsystem identifier
    ///   - file: The file path (automatically filled by compiler)
    /// - Returns: Configured Logger instance
    ///
    /// Usage:
    /// ```swift
    /// private let logger = Logger.forCaller(subsystem: "SwiftUICalendar")
    /// // Category will be derived from the filename
    /// ```
    public static func forCaller(
        subsystem: String,
        file: String = #file
    ) -> Logger {
        // Extract type name from file path
        // e.g., "CalendarViewModel.swift" -> "CalendarViewModel"
        let fileName = (file as NSString).lastPathComponent
        let typeName = (fileName as NSString).deletingPathExtension
        return Logger(subsystem: subsystem, category: typeName)
    }

    // MARK: Privacy Helpers

    // Note: OSLog privacy must be compile-time constants, so we provide
    // separate methods for each privacy level rather than a parameter

    /// Log a debug message with public privacy (always visible in logs)
    /// - Parameter message: The message to log
    public func debugPublic(_ message: String) {
        self.debug("\(message, privacy: .public)")
    }

    /// Log a debug message with private privacy (redacted in logs)
    /// - Parameter message: The message to log
    public func debugPrivate(_ message: String) {
        self.debug("\(message, privacy: .private)")
    }

    /// Log an info message with public privacy (always visible in logs)
    /// - Parameter message: The message to log
    public func infoPublic(_ message: String) {
        self.info("\(message, privacy: .public)")
    }

    /// Log an info message with private privacy (redacted in logs)
    /// - Parameter message: The message to log
    public func infoPrivate(_ message: String) {
        self.info("\(message, privacy: .private)")
    }

    /// Log an error message with public privacy (always visible in logs)
    /// - Parameter message: The message to log
    public func errorPublic(_ message: String) {
        self.error("\(message, privacy: .public)")
    }

    /// Log an error message with private privacy (redacted in logs)
    /// - Parameter message: The message to log
    public func errorPrivate(_ message: String) {
        self.error("\(message, privacy: .private)")
    }
}

// MARK: - Convenience Methods for Common Patterns

extension Logger {

    /// Log an error with context information.
    ///
    /// `message`, `context`, the error's type, and its `NSError` domain and code are logged
    /// **public** so they survive in production logs and sysdiagnoses; only the error's
    /// `localizedDescription` (which can embed user data such as file paths) is private. Keep
    /// `context` to identifiers and non-sensitive state — never user-entered values.
    ///
    /// - Parameters:
    ///   - message: Error description
    ///   - error: The error object
    ///   - context: Additional non-sensitive context (e.g. feature, action, IDs)
    ///   - file: Source file (automatically filled)
    ///   - function: Function name (automatically filled)
    ///   - line: Line number (automatically filled)
    ///
    /// Usage:
    /// ```swift
    /// logger.error("Failed to create date", error: someError, context: "day=\(day)")
    /// ```
    public func error(
        _ message: String,
        error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let summary = ErrorLogSummary(error)
        let contextSuffix = context.map { " | Context: \($0)" } ?? ""
        self.error(
            """
            \(message, privacy: .public)\(contextSuffix, privacy: .public) \
            | Error: \(summary.identity, privacy: .public) \
            (\(summary.localizedDescription, privacy: .private)) \
            | \(fileName, privacy: .public):\(line, privacy: .public) \(function, privacy: .public)
            """
        )
    }

    /// Log function entry (useful for debugging control flow)
    ///
    /// The function name and `message` are logged public; keep `message` free of user data.
    /// - Parameters:
    ///   - message: Optional message to append
    ///   - function: Function name (automatically filled)
    ///
    /// Usage:
    /// ```swift
    /// logger.traceEntry("Starting month update")
    /// ```
    public func traceEntry(
        _ message: String = "",
        function: String = #function
    ) {
        if message.isEmpty {
            self.debug("→ \(function, privacy: .public)")
        } else {
            self.debug("→ \(function, privacy: .public) | \(message, privacy: .public)")
        }
    }

    /// Log function exit (useful for debugging control flow)
    ///
    /// The function name and `message` are logged public; keep `message` free of user data.
    /// - Parameters:
    ///   - message: Optional message to append
    ///   - function: Function name (automatically filled)
    ///
    /// Usage:
    /// ```swift
    /// logger.traceExit("Completed successfully")
    /// ```
    public func traceExit(
        _ message: String = "",
        function: String = #function
    ) {
        if message.isEmpty {
            self.debug("← \(function, privacy: .public)")
        } else {
            self.debug("← \(function, privacy: .public) | \(message, privacy: .public)")
        }
    }
}

/// The non-sensitive, publicly loggable identity of an error, plus its private description.
struct ErrorLogSummary: Equatable {
    /// Type, domain, and code, e.g. `URLError (NSURLErrorDomain -1009)`.
    let identity: String
    /// The error's `localizedDescription`; may contain user data, so log it privately.
    let localizedDescription: String

    init(_ error: Error) {
        if let snapshot = error as? AnySendableError {
            // Log the wrapped error's identity, not the wrapper's.
            identity = "\(snapshot.typeName) (\(snapshot.domain) \(snapshot.code))"
            localizedDescription = snapshot.localizedDescription
            return
        }
        let nsError = error as NSError
        identity =
            "\(String(reflecting: type(of: error))) (\(nsError.domain) \(nsError.code))"
        localizedDescription = error.localizedDescription
    }
}
