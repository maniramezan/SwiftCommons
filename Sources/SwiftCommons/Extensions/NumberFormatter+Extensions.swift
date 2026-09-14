import Foundation
import OSLog

extension NumberFormatter {
    /// Cache key for the built-in `NumberFormatter` caching helpers below.
    struct CacheKey: Hashable {
        let locale: Locale
        let style: Style
        let currencyCode: String?
        let fractionDigits: ClosedRange<Int>?
        let usesGroupingSeparator: Bool?

        init(
            locale: Locale, style: Style, currencyCode: String? = nil,
            fractionDigits: ClosedRange<Int>? = nil, usesGroupingSeparator: Bool? = nil
        ) {
            self.locale = locale
            self.style = style
            self.currencyCode = currencyCode
            self.fractionDigits = fractionDigits
            self.usesGroupingSeparator = usesGroupingSeparator
        }
    }

    private static let logger: Logger = .swiftCommonsLogger(for: NumberFormatter.self)

    /// Returns a thread-local cached `NumberFormatter` for the given locale.
    private static func cachedFormatter(
        locale: Locale, style: Style = .none, currencyCode: String? = nil
    ) -> NumberFormatter {
        FormatterCache.formatter(
            for: CacheKey(locale: locale, style: style, currencyCode: currencyCode)
        ) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = style
            if let currencyCode {
                formatter.currencyCode = currencyCode
            }
            return formatter
        }
    }

    /// Formats a year value using the provided locale.
    ///
    /// Digit glyphs follow whatever numbering system is encoded in `locale`. Use
    /// ``Foundation/Locale/withNumberingSystemIdentifier(_:)`` to request a
    /// specific numbering system (e.g. Eastern Arabic-Indic digits).
    public static func formatYear(_ year: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale)
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
        let formatter = cachedFormatter(locale: locale)
        guard let formatted = formatter.string(from: value as NSNumber) else {
            logger.errorPublic("Failed to format day: \(value)")
            return String(value)
        }
        return formatted
    }

    /// Formats a number as a localized ordinal (e.g., "1st", "2nd", "3rd" in US English).
    ///
    /// Digit glyphs and ordinal suffixes follow whatever numbering system and locale rules
    /// are encoded in `locale`.
    public static func formatOrdinal(_ value: Int, locale: Locale = .current) -> String {
        let formatter = cachedFormatter(locale: locale, style: .ordinal)
        guard let formatted = formatter.string(from: value as NSNumber) else {
            logger.errorPublic("Failed to format ordinal: \(value)")
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
        let formatter = cachedFormatter(
            locale: locale,
            style: .currency, currencyCode: currencyCode
        )
        guard let formatted = formatter.string(from: amount as NSDecimalNumber) else {
            logger.errorPublic("Failed to format currency amount")
            return String(describing: amount)
        }
        return formatted
    }

    /// Formats a decimal number with localized separators and optional grouping.
    /// - Parameters:
    ///   - value: The number to format without converting it to binary floating point.
    ///   - fractionDigits: The inclusive range of displayed fraction digits; must be nonnegative.
    ///   - usesGroupingSeparator: Whether to group digits, such as `1,234` in US English.
    ///   - locale: The display locale. Defaults to `.current`.
    /// - Returns: The formatted number, or its plain numeric value if formatting fails.
    public static func formatDecimal(
        _ value: Decimal,
        fractionDigits: ClosedRange<Int> = 0...3,
        usesGroupingSeparator: Bool = true,
        locale: Locale = .current
    ) -> String {
        formatNumber(
            value, style: .decimal, fractionDigits: fractionDigits,
            usesGroupingSeparator: usesGroupingSeparator, locale: locale)
    }

    /// Formats a ratio as a localized percentage (`0.25` becomes `25%` in US English).
    /// - Parameters:
    ///   - value: The ratio to format; `1` represents 100 percent.
    ///   - fractionDigits: The inclusive range of displayed fraction digits; must be nonnegative.
    ///   - locale: The display locale. Defaults to `.current`.
    /// - Returns: The formatted percentage, or the plain ratio if formatting fails.
    public static func formatPercent(
        _ value: Decimal,
        fractionDigits: ClosedRange<Int> = 0...0,
        locale: Locale = .current
    ) -> String {
        formatNumber(
            value, style: .percent, fractionDigits: fractionDigits,
            usesGroupingSeparator: true, locale: locale)
    }

    private static func formatNumber(
        _ value: Decimal, style: Style, fractionDigits: ClosedRange<Int>,
        usesGroupingSeparator: Bool, locale: Locale
    ) -> String {
        precondition(fractionDigits.lowerBound >= 0, "Fraction digits must be nonnegative")
        let formatter: NumberFormatter = FormatterCache.formatter(
            for: CacheKey(
                locale: locale, style: style, fractionDigits: fractionDigits,
                usesGroupingSeparator: usesGroupingSeparator)
        ) {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = style
            formatter.minimumFractionDigits = fractionDigits.lowerBound
            formatter.maximumFractionDigits = fractionDigits.upperBound
            formatter.usesGroupingSeparator = usesGroupingSeparator
            return formatter
        }
        return formatter.string(from: value as NSDecimalNumber) ?? String(describing: value)
    }

}
