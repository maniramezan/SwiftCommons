import Foundation
import Testing

@testable import SwiftCommons

@Suite("Locale extensions")
struct LocaleExtensionsTests {
    @Test(arguments: [
        (Calendar.Identifier.gregorian, "en_US"),
        (Calendar.Identifier.persian, "fa_IR"),
        (Calendar.Identifier.buddhist, "en_US"),
    ])
    func initWithCalendarIdentifier(identifier: Calendar.Identifier, expected: String) {
        #expect(Locale(calendarIdentifier: identifier).identifier == expected)
    }

    @Test
    func withNumberingSystemIdentifier() {
        let base = Locale(identifier: "fa_IR")
        let modified = base.withNumberingSystemIdentifier(.arabExtended)
        #expect(modified.identifier.contains("arabext"))
    }

    @Test
    func identifierConstants() {
        #expect(Locale.Identifier.faIR == "fa_IR")
        #expect(Locale.Identifier.enUS == "en_US")
    }
}
