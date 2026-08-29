import Testing

@testable import SwiftCommons

@Suite("ConfigValue string decoding")
struct ConfigValueStringDecodingTests {

    @Test("Each type coerces its string form")
    func decodesEachType() {
        #expect(ConfigValue(string: "1", valueType: .bool) == .bool(true))
        #expect(ConfigValue(string: "off", valueType: .bool) == .bool(false))
        #expect(ConfigValue(string: "hello", valueType: .string) == .string("hello"))
        #expect(ConfigValue(string: "7", valueType: .int) == .int(7))
        #expect(ConfigValue(string: "2.5", valueType: .double) == .double(2.5))
    }

    @Test("Malformed values fail per type; string never fails")
    func rejectsMalformed() {
        #expect(ConfigValue(string: "notabool", valueType: .bool) == nil)
        #expect(ConfigValue(string: "7.5", valueType: .int) == nil)
        #expect(ConfigValue(string: "", valueType: .int) == nil)
        #expect(ConfigValue(string: "x", valueType: .double) == nil)
        #expect(ConfigValue(string: "", valueType: .string) == .string(""))
    }
}
