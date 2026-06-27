import Foundation
import Testing

@testable import SwiftCommons

@Suite("NumberFormatter extensions")
struct NumberFormatterExtensionsTests {
    @Test
    func formatYearWithDefaultLocale() {
        #expect(NumberFormatter.formatYear(2024, locale: Locale(identifier: "en_US")) == "2024")
    }

    @Test
    func formatYearWithArabicLocaleProducesNonEmptyString() {
        // Output depends on system locale data, so only verify it is non-empty.
        #expect(!NumberFormatter.formatYear(2024, locale: Locale(identifier: "ar")).isEmpty)
    }

    @Test(arguments: [
        (15, "15"),
        (5, "5"),
    ])
    func formatDay(value: Int, expected: String) {
        #expect(NumberFormatter.formatDay(value, locale: Locale(identifier: "en_US")) == expected)
    }
}
