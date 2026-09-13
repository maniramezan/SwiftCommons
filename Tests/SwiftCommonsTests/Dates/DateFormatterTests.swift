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

    @Test
    func patternFormatterAppliesCalendar() {
        var persian = Calendar(identifier: .persian)
        persian.locale = Locale(identifier: "en_US")
        let formatter = DateFormatter.formatter(dateFormat: "y", calendar: persian)
        #expect(formatter.calendar?.identifier == .persian)
    }

    @Test
    func patternFormatterCachesPerCalendarSignature() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = Locale(identifier: "en_US")
        var persian = Calendar(identifier: .persian)
        persian.locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(dateFormat: "y", calendar: gregorian)
        let f2 = DateFormatter.formatter(dateFormat: "y", calendar: persian)
        #expect(f1 !== f2)
    }

    @Test
    func templateFormatterResolvesLocalizedPattern() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        let formatter = DateFormatter.formatter(template: "yMMMMd", calendar: calendar)
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        #expect(formatter.string(from: date).contains("January"))
    }

    @Test
    func templateFormatterCachesSameInstance() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        let f1 = DateFormatter.formatter(template: "yMMMMd", calendar: calendar)
        let f2 = DateFormatter.formatter(template: "yMMMMd", calendar: calendar)
        #expect(f1 === f2)
    }
}
