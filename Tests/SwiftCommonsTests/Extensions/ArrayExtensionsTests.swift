import Testing

@testable import SwiftCommons

@Suite("Array extensions")
struct ArrayExtensionsTests {
    let array = [1, 2, 3, 4, 5, 6]

    @Test(arguments: [
        (-1, 13, 13),
        (2, 13, 3),
        (6, -1, -1),
    ])
    func fallbackIndexAccess(index: Int, defaultValue: Int, expected: Int) {
        #expect(array[index, default: defaultValue] == expected)
    }

    @Test(arguments: [
        (-1, nil),
        (6, nil),
        (2, 3),
    ])
    func safeIndexAccess(index: Int, expected: Int?) {
        #expect(array[safe: index] == expected)
    }

    @Test
    func safeRangeAccess() {
        #expect(array[safe: 6..<7] == [])
        #expect(array[0..<0, default: 13] == [])
        #expect(array[6..<7, default: 13] == [13])

        #expect(array[safe: 4..<7] == [5, 6])
        #expect(array[4..<7, default: 13] == [5, 6, 13])

        #expect(array[safe: 0..<3] == [1, 2, 3])
        #expect(array[0..<3, default: 13] == [1, 2, 3])
    }

    @Test
    func safeClosedRangeAccess() {
        #expect(array[safe: 6...7] == [])
        #expect(array[0...0, default: 13] == [1])
        #expect(array[6...7, default: 13] == [13, 13])

        #expect(array[safe: 4...7] == [5, 6])
        #expect(array[4...7, default: 13] == [5, 6, 13, 13])

        #expect(array[safe: 0...3] == [1, 2, 3, 4])
        #expect(array[0...3, default: 13] == [1, 2, 3, 4])
    }
}
