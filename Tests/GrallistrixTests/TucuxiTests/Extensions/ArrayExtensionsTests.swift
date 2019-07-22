import XCTest
@testable import Grallistrix

final class ArrayExtensionsTests: XCTestCase {
    let array = [1, 2, 3, 4, 5, 6]
    
    func testFallbackIndexAccess() {
        XCTAssertEqual(array[-1, default: 13], 13)
        XCTAssertEqual(array[2, default: 13], 3)
        XCTAssertEqual(array[6, default: -1], -1)
    }
    
    func testSafeIndexAccess() {
        XCTAssertNil(array[safe: -1])
        XCTAssertNil(array[safe: 6])
        XCTAssertEqual(array[safe: 2], 3)
    }
    
    func testSafeRangeAccess() {
        XCTAssertEqual(array[safe: 6..<7], [])
        XCTAssertEqual(array[0..<0, default: 13], [])
        XCTAssertEqual(array[6..<7, default: 13], [13])
        
        XCTAssertEqual(array[safe: 4..<7], [5, 6])
        XCTAssertEqual(array[4..<7, default: 13], [5, 6, 13])
        
        XCTAssertEqual(array[safe: 0..<3], [1, 2, 3])
        XCTAssertEqual(array[0..<3, default: 13], [1, 2, 3])
    }
    
    func testSafeClosedRangeAccess() {
        XCTAssertEqual(array[safe: 6...7], [])
        XCTAssertEqual(array[0...0, default: 13], [1])
        XCTAssertEqual(array[6...7, default: 13], [13, 13])
        
        XCTAssertEqual(array[safe: 4...7], [5, 6])
        XCTAssertEqual(array[4...7, default: 13], [5, 6, 13, 13])
        
        XCTAssertEqual(array[safe: 0...3], [1, 2, 3, 4])
        XCTAssertEqual(array[0...3, default: 13], [1, 2, 3, 4])
    }
    
    static var allTests = [
        ("testFallbackIndexAccess", testFallbackIndexAccess),
        ("testSafeIndexAccess", testSafeIndexAccess),
    ]
}
