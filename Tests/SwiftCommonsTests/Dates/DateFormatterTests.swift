import Foundation
import XCTest

@testable import SwiftCommons

final class DateFormatterTests: XCTestCase {
    func testFormatterReturnsCorrectFormat() {
        let formatter = DateFormatter.formatter(.MMddyyyy, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(formatter.dateFormat, "MM/dd/yyyy")
    }

    func testFormatterCachesPerThread() {
        let locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let f2 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        XCTAssertTrue(f1 === f2, "Should return the same cached instance")
    }

    func testDifferentFormatsReturnDifferentFormatters() {
        let locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let f2 = DateFormatter.formatter(.MMMMdd, locale: locale)
        XCTAssertFalse(f1 === f2)
    }

    func testFormatterFormatsDate() {
        let formatter = DateFormatter.formatter(
            .MMddyyyy,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "UTC")!
        )
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        XCTAssertEqual(formatter.string(from: date), "01/15/2024")
    }
}
