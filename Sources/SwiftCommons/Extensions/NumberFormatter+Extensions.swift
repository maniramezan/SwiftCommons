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

    /// Formats a year value using the provided locale.
    ///
    /// Digit glyphs follow whatever numbering system is encoded in `locale`. Use
    /// ``Foundation/Locale/withNumberingSystemIdentifier(_:)`` to request a
    /// specific numbering system (e.g. Eastern Arabic-Indic digits).
    public static func formatYear(_ year: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale, purpose: "year")
        guard let formattedYear = formatter.string(from: year as NSNumber) else {
            logger.errorPublic("Failed to format year: \(year)")
            return String(year)
        }
        return formattedYear
    }

    /// Formats a day or month index using the provided locale.
    ///
    /// Digit glyphs follow whatever numbering system is encoded in `locale`. Use
    /// ``Foundation/Locale/withNumberingSystemIdentifier(_:)`` to request a
    /// specific numbering system (e.g. Eastern Arabic-Indic digits).
    public static func formatDay(_ value: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale, purpose: "day")
        guard let formatted = formatter.string(from: value as NSNumber) else {
            logger.errorPublic("Failed to format day: \(value)")
            return String(value)
        }
        return formatted
    }

    /// Formats an amount as localized currency.
    ///
    ///     NumberFormatter.formatCurrency(9.99, currencyCode: "USD", locale: .init(identifier: "en_US")) // "$9.99"
    ///     NumberFormatter.formatCurrency(9.99, currencyCode: "EUR", locale: .init(identifier: "de_DE")) // "9,99 €"
    ///
    /// - Parameters:
    ///   - amount: The amount to format.
    ///   - currencyCode: An ISO 4217 currency code (e.g. `"USD"`). When `nil`,
    ///     the currency implied by `locale` is used.
    ///   - locale: The locale to apply. Defaults to `Locale.current`.
    /// - Returns: The formatted currency string, or the plain numeric value if
    ///   formatting fails.
    public static func formatCurrency(
        _ amount: Decimal,
        currencyCode: String? = nil,
        locale: Locale = .current
    ) -> String {
        let formatter = cachedFormatter(locale: locale, purpose: "currency|\(currencyCode ?? "")")
        formatter.numberStyle = .currency
        if let currencyCode {
            formatter.currencyCode = currencyCode
        }
        guard let formatted = formatter.string(from: amount as NSDecimalNumber) else {
            logger.errorPublic("Failed to format currency amount")
            return String(describing: amount)
        }
        return formatted
    }
}
