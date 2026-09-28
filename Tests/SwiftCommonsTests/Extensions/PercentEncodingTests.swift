import Foundation
import SwiftCommons
import Testing

@Suite("RFC 3986 component encoding")
struct PercentEncodingTests {
    @Test("Only unreserved ASCII bytes remain literal")
    func ascii() {
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        #expect(unreserved.percentEncodedRFC3986 == unreserved)
        for byte in UInt8(0)...127 {
            let text = String(UnicodeScalar(byte))
            let expected = unreserved.contains(text) ? text : String(format: "%%%02X", Int(byte))
            #expect(text.percentEncodedRFC3986 == expected)
        }
    }

    @Test("Query delimiters, spaces, and existing escapes are encoded")
    func components() {
        #expect("".percentEncodedRFC3986 == "")
        #expect("a&b=c?d /+%20".percentEncodedRFC3986 == "a%26b%3Dc%3Fd%20%2F%2B%2520")
        #expect("a&b".percentEncodedRFC3986 != "a%26b".percentEncodedRFC3986)
    }

    @Test("Unicode preserves UTF-8 bytes and normalization")
    func unicode() {
        #expect("é🙂".percentEncodedRFC3986 == "%C3%A9%F0%9F%99%82")
        #expect("e\u{301}".percentEncodedRFC3986 == "e%CC%81")
        let text = "سلام 👨‍👩‍👧‍👦"
        #expect(text.percentEncodedRFC3986.removingPercentEncoding == text)
    }
}
