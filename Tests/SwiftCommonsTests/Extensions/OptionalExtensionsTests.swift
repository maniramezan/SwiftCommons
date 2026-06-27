import Testing

@testable import SwiftCommons

@Suite("Optional extensions")
struct OptionalExtensionsTests {
    @Test
    func ifNilReturnsWrappedValueWhenPresent() {
        let value: String? = "some string"
        #expect(value.ifNil("another string") == "some string")
    }

    @Test
    func ifNilReturnsDefaultWhenNil() {
        let value: String? = nil
        #expect(value.ifNil("another string") == "another string")
    }
}
