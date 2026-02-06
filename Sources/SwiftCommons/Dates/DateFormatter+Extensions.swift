import Foundation

extension DateFormatter {
	/// Common date format templates used by SwiftCommons.
	public enum FormatType: String {
		/// "MMMM dd, yyyy" format (e.g., "January 30, 2026").
		case MMMMddyyyy = "MMMM dd, yyyy"
		/// "MMMM dd" format (e.g., "January 30").
		case MMMMdd = "MMMM dd"
		/// "MM/dd/yyyy" format (e.g., "01/30/2026").
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
        // DateFormatter is not thread-safe; cache per-thread and per (format, locale, timeZone).
        let cacheKey = "com.swiftutils.dateformatter.\(formatterType.rawValue)|\(locale.identifier)|\(timeZone.identifier)"
        let threadCache = Thread.current.threadDictionary

        if let cached = threadCache[cacheKey] as? DateFormatter {
            return cached
        }

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = timeZone
        dateFormatter.locale = locale
        dateFormatter.dateFormat = formatterType.rawValue
        threadCache[cacheKey] = dateFormatter

        return dateFormatter
	}
}
