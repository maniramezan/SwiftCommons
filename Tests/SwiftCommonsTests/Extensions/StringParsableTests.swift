import Testing

@testable import SwiftCommons

@Suite("StringParsable")
struct StringParsableTests {

    @Test("Bool accepts the loose textual spellings")
    func boolLenientParsing() {
        for text in ["true", "TRUE", "  True ", "1", "yes", "on", "ON"] {
            #expect(Bool(parsing: text) == true, "\(text) should parse as true")
        }
        for text in ["false", "FALSE", " false\n", "0", "no", "off"] {
            #expect(Bool(parsing: text) == false, "\(text) should parse as false")
        }
    }

    @Test("Bool rejects anything else")
    func boolRejectsGarbage() {
        for text in ["", "  ", "tru", "2", "yeah", "y", "n", "enabled"] {
            #expect(Bool(parsing: text) == nil, "\(text) should not parse")
        }
    }

    @Test("Numeric and string parsing defer to LosslessStringConvertible")
    func numericAndStringParsing() {
        #expect(Int(parsing: "42") == 42)
        #expect(Int(parsing: "-7") == -7)
        #expect(Int(parsing: "4.2") == nil)
        #expect(Int(parsing: "x") == nil)

        #expect(Double(parsing: "3.14") == 3.14)
        #expect(Double(parsing: "1e3") == 1000)
        #expect(Double(parsing: "x") == nil)

        #expect(String(parsing: "anything at all") == "anything at all")
    }

    @Test("Boolean flag constants and String(flag:) round-trip through Bool(parsing:)")
    func booleanFlagStrings() {
        #expect(String.enabledFlag == "1")
        #expect(String.disabledFlag == "0")
        #expect(String(flag: true) == "1")
        #expect(String(flag: false) == "0")
        #expect(Bool(parsing: String(flag: true)) == true)
        #expect(Bool(parsing: String(flag: false)) == false)
    }
}
