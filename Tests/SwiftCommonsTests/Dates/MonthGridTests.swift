import Foundation
import SwiftCommons
import Testing

@Suite("Month grids")
struct MonthGridTests {
    private func makeCalendar(
        _ identifier: Calendar.Identifier = .gregorian,
        firstWeekday: Int = 1, timeZone: String = "America/New_York"
    ) throws -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = try #require(TimeZone(identifier: timeZone))
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    @Test(arguments: [(2026, 2, 28), (2028, 2, 35), (2026, 8, 42)])
    func padsToTheRequiredNumberOfWeeks(year: Int, month: Int, count: Int) throws {
        let calendar = try makeCalendar()
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let identifier = MonthIdentifier(month: month, year: year)
        let dates = try #require(arithmetic.gridDates(in: identifier))
        let start = try #require(arithmetic.start(of: identifier))
        let expectedDayCount = try #require(calendar.range(of: .day, in: .month, for: start)).count
        #expect(dates.count == count)
        #expect(calendar.component(.weekday, from: try #require(dates.first)) == 1)
        #expect(calendar.component(.weekday, from: try #require(dates.last)) == 7)
        #expect(
            dates.filter { arithmetic.month(containing: $0) == identifier }.count
                == expectedDayCount)
    }

    @Test(arguments: [1, 2, 7])
    func respectsFirstWeekday(firstWeekday: Int) throws {
        let calendar = try makeCalendar(firstWeekday: firstWeekday)
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let dates = try #require(arithmetic.gridDates(in: MonthIdentifier(month: 1, year: 2028)))
        #expect(calendar.component(.weekday, from: try #require(dates.first)) == firstWeekday)
        #expect(dates.count.isMultiple(of: 7))
    }

    @Test(arguments: [(3, 23.0), (11, 25.0)])
    func preservesDayStartsAcrossDST(month: Int, transitionHours: Double) throws {
        let calendar = try makeCalendar()
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let dates = try #require(
            arithmetic.gridDates(in: MonthIdentifier(month: month, year: 2025)))
        #expect(dates.allSatisfy { calendar.startOfDay(for: $0) == $0 })
        let gaps = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }
        #expect(gaps.contains(transitionHours * 3600))
        #expect(gaps.allSatisfy { $0 > 0 })
    }

    @Test func preservesLeapMonthIdentity() throws {
        let calendar = try makeCalendar(.chinese)
        let gregorian = try makeCalendar(.gregorian)
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let date = try #require(gregorian.date(from: DateComponents(year: 2025, month: 7, day: 25)))
        let month = arithmetic.month(containing: date)
        try #require(month.isLeapMonth)
        let dates = try #require(arithmetic.gridDates(in: month))
        let interval = try #require(arithmetic.interval(of: month))
        let monthDates = dates.filter { $0 >= interval.start && $0 < interval.end }
        #expect(monthDates.allSatisfy { arithmetic.month(containing: $0) == month })
        #expect(monthDates.count == calendar.range(of: .day, in: .month, for: date)?.count)
        #expect(dates.count.isMultiple(of: 7))
    }

    @Test func padsEachEraSegmentIndependently() throws {
        let calendar = try makeCalendar(.japanese, timeZone: "Asia/Tokyo")
        let gregorian = try makeCalendar(.gregorian, timeZone: "Asia/Tokyo")
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let firstDate = try #require(
            gregorian.date(from: DateComponents(year: 1989, month: 1, day: 1)))
        let secondDate = try #require(
            gregorian.date(from: DateComponents(year: 1989, month: 1, day: 8)))
        let firstMonth = arithmetic.month(containing: firstDate)
        let secondMonth = arithmetic.month(containing: secondDate)
        let firstGrid = try #require(arithmetic.gridDates(in: firstMonth))
        let secondGrid = try #require(arithmetic.gridDates(in: secondMonth))

        #expect(firstGrid.count == 7)
        #expect(secondGrid.count == 28)
        #expect(firstGrid.first == firstDate)
        #expect(secondGrid.first == secondDate)
        #expect(firstGrid.allSatisfy { arithmetic.month(containing: $0) == firstMonth })
        #expect(secondGrid.filter { arithmetic.month(containing: $0) == secondMonth }.count == 24)
    }

    @Test func rejectsInvalidOrMismatchedMonth() throws {
        let arithmetic = CalendarArithmetic(calendar: try makeCalendar())
        #expect(arithmetic.gridDates(in: MonthIdentifier(month: 99, year: 2028)) == nil)
        #expect(
            arithmetic.gridDates(
                in: MonthIdentifier(
                    month: 1, year: 2028, calendarIdentifier: .persian)) == nil)
    }
}
