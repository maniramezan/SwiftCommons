import Foundation
import Testing

@testable import SwiftCommons

@Suite("URL extensions")
struct URLExtensionsTests {
    @Test
    func initWithStaticStringLiteralWorks() {
        let validURL: URL = "https://www.foo.com"
        #expect(validURL.absoluteString == "https://www.foo.com")
    }
}
