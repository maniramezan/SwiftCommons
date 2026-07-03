import Testing

@testable import SwiftCommons

@Suite("String+Extensions")
struct StringExtensionsTests {
    @Test
    func trimmedRemovesLeadingAndTrailingWhitespace() {
        #expect("  hello \n".trimmed == "hello")
        #expect("hello".trimmed == "hello")
        #expect("   ".trimmed == "")
    }

    @Test
    func isBlankDetectsEmptyAndWhitespaceOnlyStrings() {
        #expect("".isBlank)
        #expect("   ".isBlank)
        #expect("\n\t".isBlank)
        #expect(!"hi".isBlank)
        #expect(!"  hi  ".isBlank)
    }

    @Test
    func nilIfBlankReturnsNilForBlankStrings() {
        let blank: String = "   "
        #expect(blank.nilIfBlank == nil)
    }

    @Test
    func nilIfBlankReturnsTrimmedValueForNonBlankStrings() {
        #expect(" hi ".nilIfBlank == "hi")
    }
}
