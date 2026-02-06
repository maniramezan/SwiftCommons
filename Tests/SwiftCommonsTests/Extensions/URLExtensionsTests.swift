import Foundation
import XCTest

@testable import SwiftCommons

class URLExtensionsTests: XCTestCase {
    func testInitWithStaticStringLiteralWorks() {
        let validURL: URL = "https://www.foo.com"
        XCTAssertEqual(validURL.absoluteString, "https://www.foo.com")        
    }
}
