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
        let locale = Locale(calendarIdentifier: identifier)
        #expect(
            locale.language.languageCode?.identifier
                == Locale(identifier: expected).language.languageCode?.identifier)
        #expect(locale.calendar.identifier == identifier)
    }

    @Test
    func withNumberingSystemIdentifier() {
        let base = Locale(identifier: "fa_IR")
        let modified = base.withNumberingSystemIdentifier(.arabExtended)
        #expect(modified.numberingSystem.identifier == "arabext")
    }

    @Test
    func withNumberingSystemIdentifierReplacesAnExistingUnicodeExtension() {
        let base = Locale(identifier: "en-US-u-ca-gregory-nu-latn")
        let modified = base.withNumberingSystemIdentifier(.arab)

        #expect(modified.numberingSystem.identifier == "arab")
        #expect(modified.calendar.identifier == .gregorian)
    }

    @Test
    func identifierConstants() {
        #expect(Locale.Identifier.faIR == "fa_IR")
        #expect(Locale.Identifier.enUS == "en_US")
    }
}
