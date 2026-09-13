import Foundation
import SwiftCommons
import Testing

@Suite @MainActor
struct CalendarArithmeticTests {
    private func calendar(_ identifier: Calendar.Identifier = .gregorian) -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar().date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test(arguments: [Calendar.Identifier.gregorian, .persian, .hebrew, .chinese, .japanese])
    func roundTrips(identifier: Calendar.Identifier) throws {
        let calendar = calendar(identifier)
        let arithmetic = CalendarArithmetic(calendar: calendar)
        for date in [try date(2025, 7, 25), try date(1915, 6, 15), try date(2200, 3, 1)] {
            let month = arithmetic.month(containing: date)
            let start = try #require(arithmetic.start(of: month))
            #expect(arithmetic.month(containing: start) == month)
            #expect(arithmetic.interval(of: month) == calendar.dateInterval(of: .month, for: date))
            #expect(arithmetic.date(day: 1, in: month) == start)
            let next = try #require(arithmetic.month(offset: 1, from: month))
            #expect(arithmetic.month(offset: -1, from: next) == month)
            #expect(try calendar.startOfMonth(for: date) == start)
            #expect(
                try calendar.numberOfDays(for: date)
                    == calendar.range(of: .day, in: .month, for: date)?.count)
            #expect(try calendar.nextMonthFirstDate(for: date) == arithmetic.start(of: next))
            #expect(try calendar.previousMonthFirstDate(for: arithmetic.start(of: next)!) == start)
            #expect(arithmetic.months(in: month.year, relativeTo: date).contains(month))
        }
    }

    @Test func invalidInputs() throws {
        let arithmetic = CalendarArithmetic(calendar: calendar())
        for month in [
            MonthIdentifier(month: 99, year: 2025),
            MonthIdentifier(month: 1, year: 2025, calendarIdentifier: .persian),
        ] {
            #expect(arithmetic.start(of: month) == nil)
            #expect(arithmetic.interval(of: month) == nil)
            #expect(arithmetic.date(day: 1, in: month) == nil)
            #expect(arithmetic.month(offset: 1, from: month) == nil)
        }
        let february = MonthIdentifier(month: 2, year: 2025)
        #expect(arithmetic.date(day: 0, in: february) == nil)
        #expect(arithmetic.date(day: 29, in: february) == nil)
        #expect(arithmetic.months(in: 0, relativeTo: try date(2025, 1, 1)).isEmpty)
    }

    @Test func leapMonthAndEraBoundaries() throws {
        let chinese = CalendarArithmetic(calendar: calendar(.chinese))
        let regular = chinese.month(containing: try date(2025, 6, 25))
        let leap = chinese.month(containing: try date(2025, 7, 25))
        #expect(regular.month == leap.month)
        #expect(regular != leap)
        #expect(leap.isLeapMonth)
        #expect(chinese.month(offset: 1, from: regular) == leap)
        let japanese = CalendarArithmetic(calendar: calendar(.japanese))
        let april = japanese.month(containing: try date(2019, 4, 1))
        let may = japanese.month(containing: try date(2019, 5, 1))
        #expect(april.era != may.era)
        #expect(japanese.month(offset: 1, from: april) == may)
        #expect(japanese.months(in: 1, relativeTo: try date(2019, 5, 1)).first == may)
    }

    @Test func eraStartingMidMonthSplitsMonth() throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = tokyo
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = tokyo
        let arithmetic = CalendarArithmetic(calendar: japanese)
        func date(_ month: Int, _ day: Int) throws -> Date {
            try #require(gregorian.date(from: DateComponents(year: 1989, month: month, day: day)))
        }
        let january1 = try date(1, 1)
        let january7 = try date(1, 7)
        let january8 = try date(1, 8)
        let february1 = try date(2, 1)
        let june1 = try date(6, 1)
        let showa = MonthIdentifier(month: 1, year: 64, calendarIdentifier: .japanese, era: 234)
        let heisei = MonthIdentifier(month: 1, year: 1, calendarIdentifier: .japanese, era: 235)

        #expect(arithmetic.month(containing: january7) == showa)
        #expect(arithmetic.month(containing: january8) == heisei)
        #expect(arithmetic.start(of: showa) == january1)
        #expect(arithmetic.start(of: heisei) == january8)
        #expect(arithmetic.interval(of: showa) == DateInterval(start: january1, end: january8))
        #expect(arithmetic.interval(of: heisei) == DateInterval(start: january8, end: february1))
        #expect(arithmetic.date(day: 7, in: showa) == january7)
        #expect(arithmetic.date(day: 8, in: showa) == nil)
        #expect(arithmetic.date(day: 7, in: heisei) == nil)
        #expect(arithmetic.date(day: 8, in: heisei) == january8)

        let heiseiMonths = arithmetic.months(in: 1, relativeTo: june1)
        #expect(heiseiMonths.first == heisei)
        #expect(heiseiMonths.count == 12)
        #expect(arithmetic.months(in: 64, relativeTo: january7) == [showa])
    }

    @Test func hebrewYearBoundaryPreservesThirteenthMonth() throws {
        let calendar = calendar(.hebrew)
        let arithmetic = CalendarArithmetic(calendar: calendar)
        let elulDate = try #require(
            calendar.date(from: DateComponents(year: 5785, month: 13, day: 10)))
        let elul = arithmetic.month(containing: elulDate)
        let next = try #require(arithmetic.month(offset: 1, from: elul))
        #expect(next.year == 5786)
        #expect(next.month == 1)
        let nextStart = try #require(arithmetic.start(of: next))
        #expect(try calendar.nextMonthFirstDate(for: elulDate) == nextStart)
        #expect(try calendar.previousMonthFirstDate(for: nextStart) == arithmetic.start(of: elul))
        #expect(arithmetic.months(in: 5785, relativeTo: elulDate).count == 12)
        #expect(arithmetic.months(in: 5784, relativeTo: elulDate).count == 13)
    }

    @Test func dayArithmeticRespectsDST() throws {
        let arithmetic = CalendarArithmetic(calendar: calendar())
        let march = MonthIdentifier(month: 3, year: 2025)
        let before = try #require(arithmetic.date(day: 9, in: march))
        let after = try #require(arithmetic.date(day: 10, in: march))
        #expect(after.timeIntervalSince(before) == 23 * 60 * 60)
    }
}
