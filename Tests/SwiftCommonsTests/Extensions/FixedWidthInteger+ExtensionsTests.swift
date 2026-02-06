import XCTest

@testable import SwiftCommons

final class FixedWidthIntegerExtensionsTests: XCTestCase {
    func testFixedWidthIntegerToDigits() {
        XCTAssertEqual([6, 5, 4, 3, 2, 1], 123456.digits)
        XCTAssertEqual([4, 3, 2, 1], 001234.digits)
        XCTAssertEqual([4, 0, 1], 104.digits)
    }
}
