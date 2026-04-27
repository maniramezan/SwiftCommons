import Foundation
import XCTest

@testable import SwiftCommons

final class LanguageTests: XCTestCase {
    func testLanguageCodeMatchesRawValue() {
        XCTAssertEqual(Language.english.code, "en")
        XCTAssertEqual(Language.persian.code, "fa")
        XCTAssertEqual(Language.japanese.code, "ja")
    }

    func testLanguageDisplayName() {
        XCTAssertEqual(Language.english.displayName, "English")
        XCTAssertEqual(Language.persian.displayName, "Persian")
    }

    func testLanguageRoundTrip() {
        for language in Language.allCases {
            let decoded = Language(rawValue: language.rawValue)
            XCTAssertEqual(decoded, language)
        }
    }

    func testLanguageCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(Language.english)
        let decoded = try decoder.decode(Language.self, from: data)
        XCTAssertEqual(decoded, .english)
    }
}
