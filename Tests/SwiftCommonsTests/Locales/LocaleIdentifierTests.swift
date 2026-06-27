import Foundation
import Testing

@testable import SwiftCommons

@Suite("Locale identifier helpers")
struct LocaleIdentifierTests {
    @Test(arguments: [
        (Language.english, Country.unitedStates, "en-US"),
        (Language.french, Country.canada, "fr-CA"),
        (Language.portuguese, Country.brazil, "pt-BR"),
        (Language.chinese, Country.taiwan, "zh-TW"),
    ])
    func identifierWithCountry(language: Language, country: Country, expected: String) {
        #expect(Locale.identifier(language: language, country: country) == expected)
    }

    @Test(arguments: [
        (Language.english, "en"),
        (Language.japanese, "ja"),
        (Language.persian, "fa"),
    ])
    func identifierWithoutCountry(language: Language, expected: String) {
        #expect(Locale.identifier(language: language) == expected)
    }

    @Test(arguments: [
        (Locale.Identifiers.englishUS, "en-US"),
        (Locale.Identifiers.englishUK, "en-GB"),
        (Locale.Identifiers.frenchCA, "fr-CA"),
        (Locale.Identifiers.germanDE, "de-DE"),
        (Locale.Identifiers.portugueseBR, "pt-BR"),
        (Locale.Identifiers.japaneseJP, "ja-JP"),
        (Locale.Identifiers.chineseCN, "zh-CN"),
    ])
    func presetIdentifiers(preset: String, expected: String) {
        #expect(preset == expected)
    }

    @Test
    func defaultPresetIsEnglishUS() {
        #expect(Locale.Identifiers.default == Locale.Identifiers.englishUS)
        #expect(Locale.Identifiers.default == "en-US")
    }
}
