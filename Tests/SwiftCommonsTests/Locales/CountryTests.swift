import Foundation
import Testing

@testable import SwiftCommons

@Suite("Country")
struct CountryTests {
    @Test(arguments: [
        (Country.unitedStates, "US"),
        (Country.canada, "CA"),
        (Country.japan, "JP"),
        (Country.brazil, "BR"),
    ])
    func countryCodeMatchesRawValue(country: Country, code: String) {
        #expect(country.code == code)
    }

    @Test(arguments: [
        (Country.unitedStates, "United States"),
        (Country.unitedKingdom, "United Kingdom"),
        (Country.southKorea, "South Korea"),
        (Country.unitedArabEmirates, "United Arab Emirates"),
    ])
    func countryDisplayName(country: Country, expected: String) {
        #expect(country.displayName == expected)
    }

    @Test(arguments: Country.allCases)
    func everyCountryHasACodeAndDisplayName(country: Country) {
        // Codes are ISO 3166-1 alpha-2: two uppercase letters.
        #expect(country.code.count == 2)
        #expect(country.code == country.code.uppercased())
        #expect(!country.displayName.isEmpty)
    }

    @Test(arguments: Country.allCases)
    func countryRoundTrip(country: Country) {
        #expect(Country(rawValue: country.rawValue) == country)
    }

    @Test
    func countryCodable() throws {
        let data = try JSONEncoder().encode(Country.france)
        let decoded = try JSONDecoder().decode(Country.self, from: data)
        #expect(decoded == .france)
    }
}
