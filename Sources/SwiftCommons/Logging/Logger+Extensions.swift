import Foundation
import OSLog

// MARK: - Logger Extension with Helper Methods

extension Logger {

    // MARK: Automatic Category Creation

    /// Creates a logger with automatic category derived from the type
    /// - Parameters:
    ///   - subsystem: The subsystem identifier (usually package name)
    ///   - type: The type to use for category (defaults to caller's type)
    /// - Returns: Configured Logger instance
    ///
    /// Usage:
    /// ```swift
    /// private let logger = Logger.forType(subsystem: "SwiftUICalendar")
    /// // Category will be "CalendarViewModel" if called from CalendarViewModel
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

    /// Log an error with context information
    /// - Parameters:
    ///   - message: Error description
    ///   - error: The error object
    ///   - context: Additional context (e.g., function name, parameters)
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
        if let context = context {
            self.error("\(message) | Context: \(context) | Error: \(error.localizedDescription) | \(fileName):\(line)")
        } else {
            self.error("\(message) | Error: \(error.localizedDescription) | \(fileName):\(line)")
        }
    }

    /// Log function entry (useful for debugging control flow)
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
            self.debug("→ \(function)")
        } else {
            self.debug("→ \(function) | \(message)")
        }
    }

    /// Log function exit (useful for debugging control flow)
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
            self.debug("← \(function)")
        } else {
            self.debug("← \(function) | \(message)")
        }
    }
}
