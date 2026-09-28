import SwiftCommons
import Testing

@Suite("Character boundaries")
struct CharacterBoundaryTests {
    @Test("Trimming removes only repeated boundary characters")
    func trimming() {
        #expect("///users//posts///".trimmingLeading("/") == "users//posts///")
        #expect("///users//posts///".trimmingTrailing("/") == "///users//posts")
        for text in ["", "/", "///"] {
            #expect(text.trimmingLeading("/").isEmpty)
            #expect(text.trimmingTrailing("/").isEmpty)
        }
        #expect("users".trimmingLeading("/") == "users")
        #expect("users".trimmingTrailing("/") == "users")
    }

    @Test("Boundaries compare whole grapheme clusters with canonical equivalence")
    func unicodeBoundaries() {
        let family: Character = "👨‍👩‍👧‍👦"
        #expect("👨‍👩‍👧‍👦👨‍👩‍👧‍👦home".trimmingLeading(family) == "home")
        #expect("home👨‍👩‍👧‍👦👨‍👩‍👧‍👦".trimmingTrailing(family) == "home")
        #expect("e\u{301}éx".trimmingLeading("é") == "x")
        #expect("xée\u{301}".trimmingTrailing("é") == "x")
        #expect("a\u{301}".trimmingTrailing("a") == "a\u{301}")
    }

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
