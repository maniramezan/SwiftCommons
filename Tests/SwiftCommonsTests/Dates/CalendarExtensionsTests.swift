import Foundation
import XCTest

@testable import SwiftCommons

final class CalendarExtensionsTests: XCTestCase {
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

    func testMonthFromDate() {
        XCTAssertEqual(calendar.month(from: sampleDate), 1)
    }

    func testYearFromDate() {
        XCTAssertEqual(calendar.year(from: sampleDate), 2024)
    }

    func testDayFromDate() {
        XCTAssertEqual(calendar.day(from: sampleDate), 15)
    }

    func testStartOfMonth() throws {
        let start = try calendar.startOfMonth(for: sampleDate)
        XCTAssertEqual(calendar.day(from: start), 1)
        XCTAssertEqual(calendar.month(from: start), 1)
    }

    func testNumberOfDaysInMonth() throws {
        // January 2024
        XCTAssertEqual(try calendar.numberOfDays(in: 1, year: 2024), 31)
        // February 2024 (leap year)
        XCTAssertEqual(try calendar.numberOfDays(in: 2, year: 2024), 29)
        // February 2023 (non-leap)
        XCTAssertEqual(try calendar.numberOfDays(in: 2, year: 2023), 28)
    }

    func testNextMonthFirstDate() throws {
        let next = try calendar.nextMonthFirstDate(for: sampleDate)
        XCTAssertEqual(calendar.month(from: next), 2)
        XCTAssertEqual(calendar.day(from: next), 1)
    }

    func testPreviousMonthFirstDate() throws {
        let prev = try calendar.previousMonthFirstDate(for: sampleDate)
        XCTAssertEqual(calendar.month(from: prev), 12)
        XCTAssertEqual(calendar.year(from: prev), 2023)
    }

    func testNextMonthWrapDecemberToJanuary() throws {
        // Dec 15, 2024
        let dec = Date(timeIntervalSince1970: 1_734_220_800)
        let next = try calendar.nextMonthFirstDate(for: dec)
        XCTAssertEqual(calendar.month(from: next), 1)
        XCTAssertEqual(calendar.year(from: next), 2025)
    }

    func testNextYear() throws {
        let next = try calendar.nextYear(for: sampleDate)
        XCTAssertEqual(calendar.year(from: next), 2025)
        XCTAssertEqual(calendar.month(from: next), 1)
    }

    func testPreviousYear() throws {
        let prev = try calendar.previousYear(for: sampleDate)
        XCTAssertEqual(calendar.year(from: prev), 2023)
    }

    func testMonthSymbol() {
        let symbol = calendar.monthSymbol(for: sampleDate, type: .standalone)
        XCTAssertEqual(symbol, "January")
    }

    func testMonthSymbolShort() {
        let symbol = calendar.monthSymbol(for: sampleDate, type: .short)
        XCTAssertEqual(symbol, "Jan")
    }

    func testIsToday() {
        let today = Date()
        let day = calendar.day(from: today)
        let month = calendar.month(from: today)
        let year = calendar.year(from: today)
        XCTAssertTrue(calendar.isToday(day: day, month: month, year: year))
        XCTAssertFalse(calendar.isToday(day: day + 1, month: month, year: year))
    }
}
