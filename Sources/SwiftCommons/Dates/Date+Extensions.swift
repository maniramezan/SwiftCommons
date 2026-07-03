import Foundation

extension Date {
    /// Formats the receiver as a human-readable, locale-aware relative time
    /// string using `RelativeDateTimeFormatter`.
    ///
    ///     let anHourAgo = Date().addingTimeInterval(-3600)
    ///     anHourAgo.relativeDescription() // "1 hour ago"
    ///
    /// - Parameters:
    ///   - referenceDate: The date the receiver is described relative to.
    ///     Defaults to now.
    ///   - unitsStyle: The formatting style for the calendar units (e.g.
    ///     `.full` for "1 hour ago", `.abbreviated` for "1 hr. ago").
    ///     Defaults to `.full`.
    ///   - locale: The locale to apply. Defaults to `Locale.current`.
    /// - Returns: A localized, relative description of the receiver.
    public func relativeDescription(
        to referenceDate: Date = Date(),
        unitsStyle: RelativeDateTimeFormatter.UnitsStyle = .full,
        locale: Locale = .current
    ) -> String {
        let formatter = Self.cachedRelativeFormatter(unitsStyle: unitsStyle, locale: locale)
        return formatter.localizedString(for: self, relativeTo: referenceDate)
    }

    /// Returns a thread-local cached `RelativeDateTimeFormatter` for the given
    /// units style and locale.
    ///
    /// `RelativeDateTimeFormatter` is not documented as thread-safe; cache
    /// per-thread and per (style, locale) to match the pattern used by
    /// `DateFormatter.formatter(...)`.
    private static func cachedRelativeFormatter(
        unitsStyle: RelativeDateTimeFormatter.UnitsStyle,
        locale: Locale
    ) -> RelativeDateTimeFormatter {
        let cacheKey =
            "com.swiftcommons.relativedatetimeformatter.\(unitsStyle)|\(locale.identifier)"
        let threadCache = Thread.current.threadDictionary

        if let cached = threadCache[cacheKey] as? RelativeDateTimeFormatter {
            return cached
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = unitsStyle
        formatter.locale = locale
        threadCache[cacheKey] = formatter

        return formatter
    }
}
