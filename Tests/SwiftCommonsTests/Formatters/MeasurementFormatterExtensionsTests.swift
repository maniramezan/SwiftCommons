import Foundation
import Testing

@testable import SwiftCommons

@Suite("MeasurementFormatter extensions")
struct MeasurementFormatterExtensionsTests {
    @Test
    func cachedReturnsSameInstanceForSameConfiguration() {
        let f1 = MeasurementFormatter.cached(unitStyle: .short, locale: Locale(identifier: "en_US"))
        let f2 = MeasurementFormatter.cached(unitStyle: .short, locale: Locale(identifier: "en_US"))
        #expect(f1 === f2)
    }

    @Test
    func cachedReturnsDifferentInstanceForDifferentUnitStyle() {
        let f1 = MeasurementFormatter.cached(unitStyle: .short, locale: Locale(identifier: "en_US"))
        let f2 = MeasurementFormatter.cached(unitStyle: .long, locale: Locale(identifier: "en_US"))
        #expect(f1 !== f2)
    }
}
