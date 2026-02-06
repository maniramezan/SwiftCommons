import OSLog

public extension Logger {
    /// Subsystem identifier used for SwiftCommons logs.
    static let swiftCommonsSubsystem = "SwiftCommons"

    /// Returns a Logger for the SwiftCommons subsystem with the provided category.
    static func swiftCommonsLogger(category: String) -> Logger {
        Logger(subsystem: swiftCommonsSubsystem, category: category)
    }

    /// Returns a Logger for the SwiftCommons subsystem using the type name as the category.
    static func swiftCommonsLogger(for type: Any.Type) -> Logger {
        let category = String(describing: type)
        return Logger(subsystem: swiftCommonsSubsystem, category: category)
    }
}
