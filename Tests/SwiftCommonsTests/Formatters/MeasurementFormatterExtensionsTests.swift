import Foundation
import Testing

@testable import SwiftCommons

@Suite("MeasurementFormatter extensions")
struct MeasurementFormatterExtensionsTests {
    @Test
    func cachedReturnsSameInstanceForSameConfiguration() {
        let usLocale = Locale(identifier: "en_US")
        let firstShortFormatter = MeasurementFormatter.cached(unitStyle: .short, locale: usLocale)
        let secondShortFormatter = MeasurementFormatter.cached(unitStyle: .short, locale: usLocale)
        #expect(firstShortFormatter === secondShortFormatter)
    }

    @Test
    func cachedReturnsDifferentInstanceForDifferentUnitStyle() {
        let usLocale = Locale(identifier: "en_US")
        let shortFormatter = MeasurementFormatter.cached(unitStyle: .short, locale: usLocale)
        let longFormatter = MeasurementFormatter.cached(unitStyle: .long, locale: usLocale)
        #expect(shortFormatter !== longFormatter)
    }
}
