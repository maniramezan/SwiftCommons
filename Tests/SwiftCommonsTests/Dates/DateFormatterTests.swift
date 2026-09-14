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
        let firstFormatter = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let secondFormatter = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        #expect(firstFormatter === secondFormatter, "Should return the same cached instance")
    }

    @Test
    func differentFormatsReturnDifferentFormatters() {
        let locale = Locale(identifier: "en_US")
        let monthDayYearFormatter = DateFormatter.formatter(.MMMMddyyyy, locale: locale)
        let monthDayFormatter = DateFormatter.formatter(.MMMMdd, locale: locale)
        #expect(monthDayYearFormatter !== monthDayFormatter)
    }

    @Test
    func formatterFormatsDate() {
        let formatter = DateFormatter.formatter(
            .MMddyyyy,
            locale: Locale(identifier: "en_US"),
            timeZone: .gmt
        )
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        #expect(formatter.string(from: date) == "01/15/2024")
    }

    @Test
    func formatterFormatsISODate() {
        let formatter = DateFormatter.formatter(
            .yyyyMMdd, locale: Locale(identifier: "en_US"), timeZone: .gmt)
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        #expect(formatter.string(from: date) == "2024-01-15")
    }

    @Test
    func formatterFormatsEUDates() {
        let locale = Locale(identifier: "en_US")
        // Jan 15, 2024 00:00 UTC
        let date = Date(timeIntervalSince1970: 1_705_276_800)
        #expect(
            DateFormatter.formatter(.ddMMyyyy, locale: locale, timeZone: .gmt).string(from: date)
                == "15/01/2024")
        #expect(
            DateFormatter.formatter(.ddMMyyyyDotted, locale: locale, timeZone: .gmt).string(
                from: date) == "15.01.2024")
        #expect(
            DateFormatter.formatter(.ddMMMMyyyy, locale: locale, timeZone: .gmt).string(from: date)
                == "15 January 2024")
    }

    @Test
    func formatterFormatsTimePatterns() {
        let locale = Locale(identifier: "en_US")
        // Jan 15, 2024 14:30:05 UTC
        let date = Date(timeIntervalSince1970: 1_705_329_005)
        #expect(
            DateFormatter.formatter(.HHmm, locale: locale, timeZone: .gmt).string(from: date)
                == "14:30")
        #expect(
            DateFormatter.formatter(.HHmmss, locale: locale, timeZone: .gmt).string(from: date)
                == "14:30:05")
        #expect(
            DateFormatter.formatter(.hmma, locale: locale, timeZone: .gmt).string(from: date)
                == "2:30 PM")
        #expect(
            DateFormatter.formatter(.yyyyMMddHHmm, locale: locale, timeZone: .gmt).string(
                from: date) == "2024-01-15 14:30")
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
        let gregorianFormatter = DateFormatter.formatter(dateFormat: "y", calendar: gregorian)
        let persianFormatter = DateFormatter.formatter(dateFormat: "y", calendar: persian)
        #expect(gregorianFormatter !== persianFormatter)
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
        let firstFormatter = DateFormatter.formatter(template: "yMMMMd", calendar: calendar)
        let secondFormatter = DateFormatter.formatter(template: "yMMMMd", calendar: calendar)
        #expect(firstFormatter === secondFormatter)
    }

    @Test
    func weekRulesHaveSeparateCacheEntries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1
        var isoWeeks = calendar
        isoWeeks.firstWeekday = 2
        isoWeeks.minimumDaysInFirstWeek = 4
        let date = try #require(calendar.date(from: DateComponents(year: 2021, month: 1, day: 1)))
        let first = DateFormatter.formatter(dateFormat: "YYYY-ww", calendar: calendar)
        let second = DateFormatter.formatter(dateFormat: "YYYY-ww", calendar: isoWeeks)
        #expect(first !== second)
        #expect(first.string(from: date) == "2021-01")
        let expected = DateFormatter()
        expected.locale = isoWeeks.locale
        expected.calendar = isoWeeks
        expected.timeZone = isoWeeks.timeZone
        expected.dateFormat = "YYYY-ww"
        #expect(second.string(from: date) == expected.string(from: date))
        #expect(second.calendar.firstWeekday == expected.calendar.firstWeekday)
        #expect(second.calendar.minimumDaysInFirstWeek == expected.calendar.minimumDaysInFirstWeek)
        #expect(
            DateFormatter.formatter(template: "Yw", calendar: calendar)
                !== DateFormatter.formatter(template: "Yw", calendar: isoWeeks))
    }

    @Test
    func localizedStylesMatchFoundationAndCacheConfiguration() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        for identifier in ["en_US", "de_DE", "fa_IR"] {
            let locale = Locale(identifier: identifier)
            let expected = DateFormatter()
            expected.locale = locale
            expected.calendar = calendar
            expected.timeZone = calendar.timeZone
            expected.dateStyle = .long
            expected.timeStyle = .short
            let actual = DateFormatter.formatter(
                dateStyle: .long, timeStyle: .short, calendar: calendar, locale: locale)
            let date = Date(timeIntervalSince1970: 1_705_276_800)
            #expect(actual.string(from: date) == expected.string(from: date))
            #expect(
                actual
                    === DateFormatter.formatter(
                        dateStyle: .long, timeStyle: .short, calendar: calendar, locale: locale))
            #expect(
                actual
                    !== DateFormatter.formatter(
                        dateStyle: .long, timeStyle: .none, calendar: calendar, locale: locale))
        }
    }

}
