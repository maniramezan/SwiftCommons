import Foundation
import Testing

@testable import SwiftCommons

@Suite("Language")
struct LanguageTests {
    @Test(arguments: [
        (Language.english, "en"),
        (Language.persian, "fa"),
        (Language.japanese, "ja"),
    ])
    func languageCodeMatchesRawValue(language: Language, code: String) {
        #expect(language.code == code)
    }

    @Test(arguments: [
        (Language.english, "English"),
        (Language.persian, "Persian"),
        (Language.chinese, "Chinese"),
        (Language.afrikaans, "Afrikaans"),
    ])
    func languageDisplayName(language: Language, expected: String) {
        #expect(language.displayName == expected)
    }

    @Test(arguments: Language.allCases)
    func everyLanguageHasACodeAndDisplayName(language: Language) {
        // Codes are ISO 639-1: two lowercase letters.
        #expect(language.code.count == 2)
        #expect(language.code == language.code.lowercased())
        #expect(!language.displayName.isEmpty)
    }

    @Test(arguments: Language.allCases)
    func languageRoundTrip(language: Language) {
        #expect(Language(rawValue: language.rawValue) == language)
    }

    @Test
    func languageCodable() throws {
        let data = try JSONEncoder().encode(Language.english)
        let decoded = try JSONDecoder().decode(Language.self, from: data)
        #expect(decoded == .english)
    }
}
