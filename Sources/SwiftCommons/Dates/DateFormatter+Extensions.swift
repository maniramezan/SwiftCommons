import Foundation

extension DateFormatter {
    /// Cache key for the built-in `DateFormatter` caching helpers below.
    enum CacheKey: Hashable {
        enum Format: Hashable {
            case pattern(String)
            case template(String)
            case styles(DateFormatter.Style, DateFormatter.Style)
        }

        case date(format: Format, calendar: Calendar?, locale: Locale, timeZone: TimeZone)
    }

    /// Common literal date format patterns used by SwiftCommons.
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
        /// "yyyy-MM-dd" format (e.g., "2026-01-30"). ISO 8601 date, locale-agnostic and
        /// lexicographically sortable.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case yyyyMMdd = "yyyy-MM-dd"
        /// "dd/MM/yyyy" format (e.g., "30/01/2026"). Day-first, slash-separated — the common
        /// EU/UK short numeric format.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case ddMMyyyy = "dd/MM/yyyy"
        /// "dd.MM.yyyy" format (e.g., "30.01.2026"). Day-first, dot-separated — common in
        /// Germany, Austria, and other Central/Eastern European locales.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case ddMMyyyyDotted = "dd.MM.yyyy"
        /// "dd MMMM yyyy" format (e.g., "30 January 2026"). Day-first long form used across
        /// the EU and UK.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case ddMMMMyyyy = "dd MMMM yyyy"
        /// "HH:mm" format (e.g., "14:30"). 24-hour time, no seconds.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case HHmm = "HH:mm"
        /// "HH:mm:ss" format (e.g., "14:30:05"). 24-hour time with seconds.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case HHmmss = "HH:mm:ss"
        /// "h:mm a" format (e.g., "2:30 PM"). 12-hour time with AM/PM marker.
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case hmma = "h:mm a"
        /// "yyyy-MM-dd HH:mm" format (e.g., "2026-01-30 14:30"). ISO-style date and time,
        /// space-separated (not a full ISO 8601 timestamp — use `ISO8601DateFormatter` for
        /// timezone-qualified round-tripping).
        // swift-format-ignore: AlwaysUseLowerCamelCase
        case yyyyMMddHHmm = "yyyy-MM-dd HH:mm"
    }

    /// Returns a cached date formatter for the given type, locale, and time zone.
    /// - Parameters:
    ///   - formatterType: The literal date format pattern to use.
    ///   - locale: The locale to apply.
    ///   - timeZone: The time zone to apply.
    public static func formatter(
        _ formatterType: FormatType,
        locale: Locale = Locale.current,
        timeZone: TimeZone = TimeZone.current
    ) -> DateFormatter {
        FormatterCache.formatter(
            for: DateFormatter.CacheKey.date(
                format: .pattern(formatterType.rawValue), calendar: nil,
                locale: locale, timeZone: timeZone)
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
            for: DateFormatter.CacheKey.date(
                format: .pattern(dateFormat), calendar: calendar,
                locale: resolvedLocale, timeZone: calendar.timeZone)
        ) {
            let formatter = DateFormatter()
            formatter.locale = resolvedLocale
            formatter.calendar = calendar
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
            for: DateFormatter.CacheKey.date(
                format: .template(template), calendar: calendar,
                locale: resolvedLocale, timeZone: calendar.timeZone)
        ) {
            let formatter = DateFormatter()
            formatter.locale = resolvedLocale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate(template)
            return formatter
        }
    }

    /// Returns a cached formatter for localized date and time styles.
    ///
    /// Use `.none` for either style to display only the other component. Treat the returned
    /// formatter as read-only and use it synchronously on the calling thread.
    /// - Parameters:
    ///   - dateStyle: The localized date detail level. Defaults to `.medium`.
    ///   - timeStyle: The localized time detail level. Defaults to `.none`.
    ///   - calendar: The calendar and time zone to use. Defaults to `.current`.
    ///   - locale: The display locale; defaults to the calendar's locale or calendar identifier.
    public static func formatter(
        dateStyle: Style = .medium,
        timeStyle: Style = .none,
        calendar: Calendar = .current,
        locale: Locale? = nil
    ) -> DateFormatter {
        let resolvedLocale =
            locale ?? calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
        return FormatterCache.formatter(
            for: DateFormatter.CacheKey.date(
                format: .styles(dateStyle, timeStyle), calendar: calendar,
                locale: resolvedLocale, timeZone: calendar.timeZone)
        ) {
            let formatter = DateFormatter()
            formatter.locale = resolvedLocale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateStyle = dateStyle
            formatter.timeStyle = timeStyle
            return formatter
        }
    }

}
