import Foundation
import OSLog

extension NumberFormatter {
    private static let yearFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }()

    private static let dayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }()

    private static let logger: Logger = .swiftCommonsLogger(for: NumberFormatter.self)

    /// Formats a year value using the provided locale and numbering system.
    public static func formatYear(_ year: Int, locale: Locale = .current) -> String {
        yearFormatter.locale = locale
        guard let formattedYear = yearFormatter.string(from: year as NSNumber) else {
            logger.errorPublic("Failed to format year: \(year)")
            return String(year)
        }
        return formattedYear
    }

    /// Formats a day or month index using the provided locale and numbering system.
    public static func formatDay(_ value: Int, locale: Locale = .current) -> String {
        dayFormatter.locale = locale
        guard let formatted = dayFormatter.string(from: value as NSNumber) else {
            logger.errorPublic("Failed to format day: \(value)")
            return String(value)
        }
        return formatted
    }
}
