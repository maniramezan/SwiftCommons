import Foundation
import OSLog

extension NumberFormatter {
    private static let logger: Logger = .swiftCommonsLogger(for: NumberFormatter.self)

    /// Returns a thread-local cached `NumberFormatter` for the given locale.
    private static func cachedFormatter(locale: Locale, purpose: String) -> NumberFormatter {
        let cacheKey = "com.swiftcommons.numberformatter.\(purpose)|\(locale.identifier)"
        let threadCache = Thread.current.threadDictionary

        if let cached = threadCache[cacheKey] as? NumberFormatter {
            return cached
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.locale = locale
        threadCache[cacheKey] = formatter
        return formatter
    }

    /// Formats a year value using the provided locale and numbering system.
    public static func formatYear(_ year: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale, purpose: "year")
        guard let formattedYear = formatter.string(from: year as NSNumber) else {
            logger.errorPublic("Failed to format year: \(year)")
            return String(year)
        }
        return formattedYear
    }

    /// Formats a day or month index using the provided locale and numbering system.
    public static func formatDay(_ value: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale, purpose: "day")
        guard let formatted = formatter.string(from: value as NSNumber) else {
            logger.errorPublic("Failed to format day: \(value)")
            return String(value)
        }
        return formatted
    }
}
