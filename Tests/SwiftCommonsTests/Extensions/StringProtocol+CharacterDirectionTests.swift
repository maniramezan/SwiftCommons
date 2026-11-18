import Foundation
import SwiftCommons
import Testing

@Suite("First strong character direction")
struct FirstStrongCharacterDirectionTests {
    @Test(
        "Left-to-right scripts",
        arguments: ["Hello, world.", "Привет", "こんにちは", "Γειά σου", "नमस्ते"]
    )
    func leftToRight(text: String) {
        #expect(text.firstStrongCharacterDirection == .leftToRight)
    }

    @Test("Right-to-left scripts", arguments: ["مرحبا", "سلام دنیا", "שלום", "ܫܠܡܐ", "𞤀𞤣𞤤𞤢𞤥"])
    func rightToLeft(text: String) {
        #expect(text.firstStrongCharacterDirection == .rightToLeft)
    }

    @Test("Leading neutrals are skipped until the first letter")
    func leadingNeutrals() {
        #expect("- [Ana] Hello".firstStrongCharacterDirection == .leftToRight)
        #expect("12, - مرحبا".firstStrongCharacterDirection == .rightToLeft)
        #expect("«۳» שלום, hello".firstStrongCharacterDirection == .rightToLeft)
    }

    @Test("Text without letters has no direction", arguments: ["", "123 ...", "🙂 !?", "۱۲۳"])
    func noLetters(text: String) {
        #expect(text.firstStrongCharacterDirection == nil)
    }

    @Test("Works on substrings")
    func substring() {
        let text = "Hello مرحبا"
        let arabic = text[text.index(text.startIndex, offsetBy: 6)...]
        #expect(arabic.firstStrongCharacterDirection == .rightToLeft)
    }
}
