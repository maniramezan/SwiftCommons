import RegexBuilder
import SwiftCommons
import Testing

@Suite("Suffix trimming")
struct SuffixTrimmingTests {
    @Test("Predicate removes repeated trailing characters and preserves the original")
    func predicate() {
        for (text, expected) in [
            ("", ""), ("///", ""), ("users", "users"), ("/users///", "/users"),
        ] {
            let result: Substring = text.trimmingSuffix(while: { $0 == "/" })
            #expect(result == expected)
            var value = text
            value.trimSuffix(while: { $0 == "/" })
            #expect(value == expected)
        }
        #expect("xée\u{301}".trimmingSuffix(while: { $0 == "é" }) == "x")
        #expect("a\u{301}".trimmingSuffix(while: { $0 == "a" }) == "a\u{301}")
        #expect("home👨‍👩‍👧‍👦👨‍👩‍👧‍👦".trimmingSuffix(while: { $0 == "👨‍👩‍👧‍👦" }) == "home")
    }

    @Test("Sequence removes one suffix, matching Swift prefix semantics")
    func sequence() {
        for (text, suffix, expected) in [
            ("file.tar.gz", ".gz", "file.tar"), ("users///", "/", "users//"),
            ("abc", "", "abc"), ("", "x", ""), ("abc", "abcd", "abc"),
            ("abc", "ac", "abc"), ("abc", "abc", ""), ("café", "e\u{301}", "caf"),
        ] {
            #expect(text.trimmingSuffix(suffix) == expected)
            var value = text
            value.trimSuffix(suffix)
            #expect(value == expected)
        }
        #expect("users///".trimmingSuffix("/") == "users//")
        #expect("abc".trimmingSuffix(AnySequence("bc")) == "a")
    }

    @Test("Collection and slice variants keep valid indices")
    func collections() {
        var values = [1, 2, 3, 3]
        #expect(Array(values.trimmingSuffix([3])) == [1, 2, 3])
        values.trimSuffix(while: { $0 == 3 })
        #expect(values == [1, 2])
        values.trimSuffix([2])
        #expect(values == [1])
        var slice = [0, 1, 2, 2][1...]
        slice.trimSuffix([2])
        #expect(Array(slice) == [1, 2])
        slice.trimSuffix(while: { $0 == 2 })
        #expect(Array(slice) == [1])
        var text = "skip/users///".dropFirst(4)
        text.trimSuffix("/")
        #expect(text == "/users//")
        text.trimSuffix(while: { $0 == "/" })
        #expect(text == "/users")
    }

    private enum Failure: Error { case predicate }

    @Test("Throwing predicates propagate errors without partial mutation")
    func throwingPredicate() {
        var text = "abc///"
        #expect(throws: Failure.self) {
            try text.trimSuffix { character in
                if character == "c" { throw Failure.predicate }
                return character == "/"
            }
        }
        #expect(text == "abc///")
        #expect(throws: Failure.self) {
            try text.trimmingSuffix { _ in throw Failure.predicate }
        }
    }

    @Test("Regex is anchored to the end and respects alternation and empty matches")
    func regex() throws {
        let digits = try Regex("[0-9]+")
        #expect("abc123".trimmingSuffix(digits) == "abc")
        #expect("123abc".trimmingSuffix(digits) == "123abc")
        #expect("abc123\n".trimmingSuffix(digits) == "abc123\n")
        #expect("xabc".trimmingSuffix(try Regex("ab|abc")) == "x")
        #expect("abc".trimmingSuffix(try Regex("")) == "abc")
        #expect("".trimmingSuffix(digits).isEmpty)
        var text = "skip/abc123".dropFirst(4)
        text.trimSuffix(digits)
        #expect(text == "/abc")
        var whole = "abc123"
        whole.trimSuffix(digits)
        #expect(whole == "abc")
        let repeatedSlash = Regex { OneOrMore { "/" } }
        #expect("users///".trimmingSuffix(repeatedSlash) == "users")
    }
}
