import Testing

@testable import SwiftCommons

@Suite("FixedWidthInteger extensions")
struct FixedWidthIntegerExtensionsTests {
    @Test(arguments: [
        (123456, [6, 5, 4, 3, 2, 1]),
        (001234, [4, 3, 2, 1]),
        (104, [4, 0, 1]),
        (0, [0]),
        (1, [1]),
        (-1234, [-4, -3, -2, -1]),
        (-1, [-1]),
    ])
    func digits(value: Int, expected: [Int]) {
        #expect(value.digits == expected)
    }

    @Test
    func digitsAreSafeForExtremeValues() {
        // `Int.min` cannot be negated; the implementation must not crash.
        #expect(Int.min.digits.count == String(Int.min).count - 1)  // minus the "-"
        // Unsigned values larger than `Int.max` must still work.
        #expect(UInt64.max.digits == String(UInt64.max).reversed().map { Int(String($0))! })
    }
}
