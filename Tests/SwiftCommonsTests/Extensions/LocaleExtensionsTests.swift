import Foundation
import XCTest

@testable import SwiftCommons

final class LocaleExtensionsTests: XCTestCase {
    func testInitWithGregorianCalendar() {
        let locale = Locale(calendarIdentifier: .gregorian)
        XCTAssertEqual(locale.identifier, "en_US")
    }

    func testInitWithPersianCalendar() {
        let locale = Locale(calendarIdentifier: .persian)
        XCTAssertEqual(locale.identifier, "fa_IR")
    }

    func testInitWithUnknownCalendarDefaultsToEnUS() {
        let locale = Locale(calendarIdentifier: .buddhist)
        XCTAssertEqual(locale.identifier, "en_US")
    }

    func testWithNumberingSystemIdentifier() {
        let base = Locale(identifier: "fa_IR")
        let modified = base.withNumberingSystemIdentifier(.arabExtended)
        XCTAssertTrue(modified.identifier.contains("arabext"))
    }

    func testIdentifierConstants() {
        XCTAssertEqual(Locale.Identifier.faIR, "fa_IR")
        XCTAssertEqual(Locale.Identifier.enUS, "en_US")
    }
}
