import SwiftCommons
import Testing

@Suite("Character boundaries")
struct CharacterBoundaryTests {
    @Test("Ensuring a first character preserves repetitions and handles empty strings")
    func ensuringFirstCharacter() {
        #expect("users".ensuringStarts(with: "/") == "/users")
        #expect("/users".ensuringStarts(with: "/") == "/users")
        #expect("///users".ensuringStarts(with: "/") == "///users")
        #expect("".ensuringStarts(with: "/") == "/")
        #expect("éclair".ensuringStarts(with: "e\u{301}") == "éclair")
        #expect("home".ensuringStarts(with: "🏠") == "🏠home")
    }

    @Test("Alphanumeric includes Unicode letters and numbers", arguments: Array("Az09é中۳½"))
    func alphanumeric(character: Character) {
        #expect(character.isAlphanumeric)
    }

    @Test("Alphanumeric excludes punctuation, whitespace, and emoji", arguments: Array("-_ .\n🙂"))
    func nonAlphanumeric(character: Character) {
        #expect(!character.isAlphanumeric)
    }

    @Test("Combining marks are classified as part of their character")
    func combiningMarks() {
        #expect(Character("e\u{301}").isAlphanumeric)
        #expect(!Character("\u{301}").isAlphanumeric)
    }
}
