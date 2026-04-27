import Foundation
import XCTest

@testable import SwiftCommons

final class NumberFormatterExtensionsTests: XCTestCase {
    func testFormatYearWithDefaultLocale() {
        let result = NumberFormatter.formatYear(2024, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result, "2024")
    }

    func testFormatYearWithArabicLocale() {
        let locale = Locale(identifier: "ar")
        let result = NumberFormatter.formatYear(2024, locale: locale)
        // Just verify it produces a non-empty string (output depends on system locale data)
        XCTAssertFalse(result.isEmpty)
    }

    func testFormatDay() {
        let result = NumberFormatter.formatDay(15, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result, "15")
    }

    func testFormatDaySingleDigit() {
        let result = NumberFormatter.formatDay(5, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(result, "5")
    }
}
