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

    @Test
    func formatCurrencyWithExplicitCurrencyCode() {
        let formatted = NumberFormatter.formatCurrency(
            9.99, currencyCode: "USD", locale: Locale(identifier: "en_US"))
        #expect(formatted == "$9.99")
    }

    @Test
    func formatCurrencyUsesLocaleImpliedCurrencyWhenCodeIsNil() {
        // No explicit currencyCode: the locale's own currency is used.
        let formatted = NumberFormatter.formatCurrency(9.99, locale: Locale(identifier: "en_US"))
        #expect(formatted == "$9.99")
    }

    @Test
    func formatCurrencyWithDifferentCurrencyCodesDoesNotShareCache() {
        let usd = NumberFormatter.formatCurrency(
            1, currencyCode: "USD", locale: Locale(identifier: "en_US"))
        let eur = NumberFormatter.formatCurrency(
            1, currencyCode: "EUR", locale: Locale(identifier: "en_US"))
        #expect(usd == "$1.00")
        #expect(eur.contains("€"))
    }
}
