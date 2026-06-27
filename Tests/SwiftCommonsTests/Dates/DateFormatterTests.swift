import Foundation
import Testing

@testable import SwiftCommons

@Suite("DateFormatter extensions")
struct DateFormatterTests {
    @Test
    func formatterReturnsCorrectFormat() {
        let formatter = DateFormatter.formatter(.MMddyyyy, locale: Locale(identifier: "en_US"))
        #expect(formatter.dateFormat == "MM/dd/yyyy")
    }

    @Test
    func formatterCachesPerThread() {
        let locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let f2 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        #expect(f1 === f2, "Should return the same cached instance")
    }

    @Test
    func differentFormatsReturnDifferentFormatters() {
        let locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let f2 = DateFormatter.formatter(.MMMMdd, locale: locale)
        #expect(f1 !== f2)
    }

    @Test
    func formatterFormatsDate() {
        let formatter = DateFormatter.formatter(
            .MMddyyyy,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "UTC")!
        )
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        #expect(formatter.string(from: date) == "01/15/2024")
    }
}
