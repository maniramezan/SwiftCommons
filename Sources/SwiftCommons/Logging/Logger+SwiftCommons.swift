import OSLog

extension Logger {
    /// Subsystem identifier used for SwiftCommons logs.
    public static let swiftCommonsSubsystem = "SwiftCommons"

    /// Returns a Logger for the SwiftCommons subsystem with the provided category.
    public static func swiftCommonsLogger(category: String) -> Logger {
        Logger(subsystem: swiftCommonsSubsystem, category: category)
    }

    /// Returns a Logger for the SwiftCommons subsystem using the type name as the category.
    public static func swiftCommonsLogger(for type: Any.Type) -> Logger {
        let category = String(describing: type)
        return Logger(subsystem: swiftCommonsSubsystem, category: category)
    }
}
