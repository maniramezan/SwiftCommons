import Foundation
import Testing

@testable import SwiftCommons

@Suite("Calendar extensions")
struct CalendarExtensionsTests {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.locale = Locale(identifier: "en_US")
        cal.firstWeekday = 1  // Sunday
        return cal
    }

    // Jan 15, 2024 12:00 UTC
    private var sampleDate: Date {
        Date(timeIntervalSince1970: 1_705_320_000)
    }

    @Test
    func componentsFromDate() {
        #expect(calendar.month(from: sampleDate) == 1)
        #expect(calendar.year(from: sampleDate) == 2024)
        #expect(calendar.day(from: sampleDate) == 15)
    }

    @Test
    func datesThroughSameDayReturnsSingleStartOfDay() throws {
        let date = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 12)))

        let dates = calendar.dates(from: date, through: date)

        #expect(dates == [calendar.startOfDay(for: date)])
    }

    @Test
    func datesThroughReturnsInclusiveSequence() throws {
        let start = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 1, day: 29, hour: 12)))
        let end = try #require(
            calendar.date(from: DateComponents(year: 2024, month: 2, day: 2, hour: 12)))

        let dates = calendar.dates(from: start, through: end)

        #expect(dates.count == 5)
        #expect(dates.map { calendar.day(from: $0) } == [29, 30, 31, 1, 2])
        #expect(dates.allSatisfy { $0 == calendar.startOfDay(for: $0) })
    }

    @Test
    func datesThroughWithStartAfterEndReturnsEmpty() throws {
        let start = try #require(calendar.date(from: DateComponents(year: 2024, month: 1, day: 16)))
        let end = try #require(calendar.date(from: DateComponents(year: 2024, month: 1, day: 15)))

        #expect(calendar.dates(from: start, through: end).isEmpty)
    }

    @Test
    func startOfMonth() throws {
        let start = try calendar.startOfMonth(for: sampleDate)
        #expect(calendar.day(from: start) == 1)
        #expect(calendar.month(from: start) == 1)
    }

    @Test
    func startOfWeek() throws {
        // Week containing Mon Jan 15, 2024 begins on Sun Jan 14 (firstWeekday = Sunday).
        let start = try calendar.startOfWeek(of: sampleDate)
        #expect(calendar.year(from: start) == 2024)
        #expect(calendar.month(from: start) == 1)
        #expect(calendar.day(from: start) == 14)
    }

    @Test
    func startOfMonthDay() throws {
        // Jan 1, 2024 is a Monday → weekday index 2 (Sunday = 1).
        #expect(try calendar.startOfMonthDay(for: sampleDate) == 2)
    }

    @Test
    func numberOfDaysForDate() throws {
        // January 2024
        #expect(try calendar.numberOfDays(for: sampleDate) == 31)
    }

    @Test(arguments: [
        (1, 2024, 31),  // January
        (2, 2024, 29),  // February (leap year)
        (2, 2023, 28),  // February (non-leap)
    ])
    func numberOfDaysInMonth(month: Int, year: Int, expected: Int) throws {
        #expect(try calendar.numberOfDays(in: month, year: year) == expected)
    }

    @Test
    func nextMonthFirstDate() throws {
        let next = try calendar.nextMonthFirstDate(for: sampleDate)
        #expect(calendar.month(from: next) == 2)
        #expect(calendar.day(from: next) == 1)
    }

    @Test
    func previousMonthFirstDate() throws {
        let prev = try calendar.previousMonthFirstDate(for: sampleDate)
        #expect(calendar.month(from: prev) == 12)
        #expect(calendar.year(from: prev) == 2023)
    }

    @Test
    func nextMonthWrapsDecemberToJanuary() throws {
        // Dec 15, 2024
        let dec = Date(timeIntervalSince1970: 1_734_220_800)
        let next = try calendar.nextMonthFirstDate(for: dec)
        #expect(calendar.month(from: next) == 1)
        #expect(calendar.year(from: next) == 2025)
    }

    @Test
    func nextYear() throws {
        let next = try calendar.nextYear(for: sampleDate)
        #expect(calendar.year(from: next) == 2025)
        #expect(calendar.month(from: next) == 1)
    }

    @Test
    func previousYear() throws {
        let prev = try calendar.previousYear(for: sampleDate)
        #expect(calendar.year(from: prev) == 2023)
    }

    @Test
    func updateYearPreservesMonthAndDay() throws {
        let updated = try calendar.updateYear(2030, for: sampleDate)
        #expect(calendar.year(from: updated) == 2030)
        #expect(calendar.month(from: updated) == 1)
        #expect(calendar.day(from: updated) == 15)
    }

    @Test
    func updateMonthPreservesDay() throws {
        let updated = try calendar.updateMonth(6, for: sampleDate)
        #expect(calendar.month(from: updated) == 6)
        #expect(calendar.day(from: updated) == 15)
        #expect(calendar.year(from: updated) == 2024)
    }

    @Test(arguments: [
        (Calendar.NameType.standalone, "January"),
        (Calendar.NameType.short, "Jan"),
        (Calendar.NameType.veryShort, "J"),
        (Calendar.NameType.veryShortStandalone, "J"),
    ])
    func monthSymbol(type: Calendar.NameType, expected: String) {
        #expect(calendar.monthSymbol(for: sampleDate, type: type) == expected)
    }

    @Test
    func isToday() {
        let today = Date()
        let day = calendar.day(from: today)
        let month = calendar.month(from: today)
        let year = calendar.year(from: today)
        #expect(calendar.isToday(day: day, month: month, year: year))
        #expect(!calendar.isToday(day: day + 1, month: month, year: year))
    }
}
