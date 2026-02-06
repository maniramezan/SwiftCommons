import XCTest

@testable import SwiftCommons

class OptionalExtensionsTests: XCTestCase {
    func testIfNilExtension() {
        
        var nonNil: String? = "some string"
        XCTAssertEqual(nonNil.ifNil("another string"), "some string")
        
        nonNil = nil
        XCTAssertEqual(nonNil.ifNil("another string"), "another string")
    }
}
