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

    @Test(arguments: [
        (1, "1st"),
        (2, "2nd"),
        (3, "3rd"),
        (4, "4th"),
        (11, "11th"),
        (12, "12th"),
        (21, "21st"),
    ])
    func formatOrdinal(value: Int, expected: String) {
        #expect(
            NumberFormatter.formatOrdinal(value, locale: Locale(identifier: "en_US")) == expected)
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
        let dollarAmount = NumberFormatter.formatCurrency(
            1, currencyCode: "USD", locale: Locale(identifier: "en_US"))
        let euroAmount = NumberFormatter.formatCurrency(
            1, currencyCode: "EUR", locale: Locale(identifier: "en_US"))
        #expect(dollarAmount == "$1.00")
        #expect(euroAmount.contains("€"))
    }

    @Test
    func decimalsRespectPrecisionGroupingAndLocale() throws {
        let usLocale = Locale(identifier: "en_US")
        #expect(
            NumberFormatter.formatDecimal(1234.567, fractionDigits: 2...2, locale: usLocale)
                == "1,234.57"
        )
        #expect(
            NumberFormatter.formatDecimal(
                1234.5, fractionDigits: 2...2,
                usesGroupingSeparator: false, locale: usLocale) == "1234.50")
        #expect(
            NumberFormatter.formatDecimal(1234.5, fractionDigits: 0...3, locale: usLocale)
                == "1,234.5")
        #expect(
            NumberFormatter.formatDecimal(
                -1234.5, fractionDigits: 2...2,
                locale: Locale(identifier: "de_DE")) == "-1.234,50")
        let precise = try #require(Decimal(string: "9007199254740993.25"))
        #expect(
            NumberFormatter.formatDecimal(
                precise, fractionDigits: 2...2,
                usesGroupingSeparator: false, locale: usLocale) == "9007199254740993.25")
    }

    @Test
    func percentagesUseRatiosAndIndependentPrecision() {
        let usLocale = Locale(identifier: "en_US")
        #expect(
            NumberFormatter.formatPercent(0.125, fractionDigits: 1...1, locale: usLocale) == "12.5%"
        )
        #expect(NumberFormatter.formatPercent(1, locale: usLocale) == "100%")
        #expect(NumberFormatter.formatPercent(0, locale: usLocale) == "0%")
        #expect(NumberFormatter.formatPercent(-0.25, locale: usLocale) == "-25%")
        #expect(NumberFormatter.formatDecimal(0.125, locale: usLocale) == "0.125")
    }

}
