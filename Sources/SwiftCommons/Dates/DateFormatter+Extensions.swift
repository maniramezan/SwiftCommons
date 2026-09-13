import Foundation

extension DateFormatter {
    /// Common date format templates used by SwiftCommons.
    public enum FormatType: String, Sendable {
        /// "MMMM dd, yyyy" format (e.g., "January 30, 2026").
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case MMMMddyyyy = "MMMM dd, yyyy"
        /// "MMMM dd" format (e.g., "January 30").
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case MMMMdd = "MMMM dd"
        /// "MM/dd/yyyy" format (e.g., "01/30/2026").
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case MMddyyyy = "MM/dd/yyyy"
    }

    /// Returns a cached date formatter for the given type, locale, and time zone.
    /// - Parameters:
    ///   - formatterType: The date format template to use.
    ///   - locale: The locale to apply.
    ///   - timeZone: The time zone to apply.
    public static func formatter(
        _ formatterType: FormatType,
        locale: Locale = Locale.current,
        timeZone: TimeZone = TimeZone.current
    ) -> DateFormatter {
        FormatterCache.formatter(
            for: "pattern|\(formatterType.rawValue)|\(locale.identifier)|\(timeZone.identifier)"
        ) {
            let formatter = DateFormatter()
            formatter.timeZone = timeZone
            formatter.locale = locale
            formatter.dateFormat = formatterType.rawValue
            return formatter
        }
    }

    /// Returns a cached, calendar-aware date formatter for a literal `dateFormat` pattern.
    ///
    /// Unlike ``formatter(_:locale:timeZone:)``, this accepts any pattern string and applies
    /// `calendar` to the formatter — required for non-Gregorian calendar systems (Persian,
    /// Hebrew, Islamic, ...), where the wrong calendar produces the wrong day/month/year numbers
    /// even with a correct locale.
    ///
    /// - Parameters:
    ///   - dateFormat: A literal `DateFormatter.dateFormat` pattern (e.g. `"MMMM d, y"`).
    ///   - calendar: The calendar system and time zone to format in.
    ///   - locale: The locale to apply. Defaults to `calendar.locale`, falling back to a locale
    ///     matching `calendar.identifier`.
    public static func formatter(
        dateFormat: String,
        calendar: Calendar,
        locale: Locale? = nil
    ) -> DateFormatter {
        let resolvedLocale =
            locale ?? calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
        return FormatterCache.formatter(
            for:
                "pattern|\(dateFormat)|\(calendar.identifier)|\(resolvedLocale.identifier)|\(calendar.timeZone.identifier)"
        ) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = resolvedLocale
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = dateFormat
            return formatter
        }
    }

    /// Returns a cached, calendar-aware date formatter resolved from a localized format
    /// template.
    ///
    /// Resolving a template (see `setLocalizedDateFormatFromTemplate(_:)`) is a locale/CLDR
    /// pattern lookup — considerably more expensive than a literal pattern, and easy to end up
    /// doing on every call in view code (e.g. an accessibility label computed per cell, per
    /// frame, in a scrolling list). Caching by (template, calendar, locale, time zone) turns
    /// that into a lookup.
    ///
    /// - Parameters:
    ///   - template: A localized date format template (e.g. `"yMMMMd"`).
    ///   - calendar: The calendar system and time zone to format in.
    ///   - locale: The locale to apply. Defaults to `calendar.locale`, falling back to a locale
    ///     matching `calendar.identifier`.
    public static func formatter(
        template: String,
        calendar: Calendar,
        locale: Locale? = nil
    ) -> DateFormatter {
        let resolvedLocale =
            locale ?? calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
        return FormatterCache.formatter(
            for:
                "template|\(template)|\(calendar.identifier)|\(resolvedLocale.identifier)|\(calendar.timeZone.identifier)"
        ) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = resolvedLocale
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }
    }
}
