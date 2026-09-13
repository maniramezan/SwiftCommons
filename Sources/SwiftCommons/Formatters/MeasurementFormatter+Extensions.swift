import Foundation

extension MeasurementFormatter {
    /// Cache key for the built-in `MeasurementFormatter` caching helper below.
    struct CacheKey: Hashable {
        let unitStyle: UnitStyle
        let unitOptions: UInt
        let locale: Locale
    }

    /// Returns a cached measurement formatter for the given unit style, options, and locale.
    ///
    /// Demonstrates ``FormatterCache`` generalizing beyond `DateFormatter`/`NumberFormatter` —
    /// any `Formatter` subclass can be cached the same way.
    public static func cached(
        unitStyle: UnitStyle = .medium,
        unitOptions: UnitOptions = .providedUnit,
        locale: Locale = .current
    ) -> MeasurementFormatter {
        FormatterCache.formatter(
            for: CacheKey(
                unitStyle: unitStyle, unitOptions: unitOptions.rawValue, locale: locale)
        ) {
            let formatter = MeasurementFormatter()
            formatter.unitStyle = unitStyle
            formatter.unitOptions = unitOptions
            formatter.locale = locale
            return formatter
        }
    }
}
