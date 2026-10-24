import Foundation
import Testing

@testable import SwiftCommonsSpeech

@Suite("TranscriptAlignment")
struct TranscriptAlignmentTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let reference: String
        let heard: String
        let statuses: [AlignedTokenStatus]

        var testDescription: String { name }
    }

    static let cases: [Case] = [
        Case(
            name: "exact match", reference: "The quick brown fox", heard: "the quick brown fox",
            statuses: [.match, .match, .match, .match]),
        Case(
            name: "missed word", reference: "The quick brown fox", heard: "the quick fox",
            statuses: [.match, .match, .omission, .match]),
        Case(
            name: "misheard word", reference: "The quick brown fox", heard: "the quick brown box",
            statuses: [.match, .match, .match, .substitution]),
        Case(
            name: "extra word", reference: "The quick fox", heard: "the very quick fox",
            statuses: [.match, .insertion, .match, .match]),
        Case(
            name: "punctuation and case", reference: "Hello, world!", heard: "hello world",
            statuses: [.match, .match]),
        Case(
            name: "curly apostrophes", reference: "Don’t stop", heard: "don't stop",
            statuses: [.match, .match]),
        Case(
            name: "hyphenated words split", reference: "A well-known fact",
            heard: "a well known fact", statuses: [.match, .match, .match, .match]),
        Case(
            name: "nothing heard", reference: "Good morning", heard: "",
            statuses: [.omission, .omission]),
        Case(
            name: "empty reference", reference: "", heard: "hi",
            statuses: [.insertion]),
    ]

    @Test(arguments: cases)
    func alignsWords(_ testCase: Case) {
        let alignment = TranscriptAlignment.align(
            reference: testCase.reference, heard: testCase.heard)
        #expect(alignment.tokens.map(\.status) == testCase.statuses)
    }

    @Test
    func keepsOriginalSpellingOfBothSides() {
        let alignment = TranscriptAlignment.align(reference: "Brown fox.", heard: "brown box")
        #expect(alignment.tokens[0].reference == "Brown")
        #expect(alignment.tokens[0].heard == "brown")
        #expect(alignment.tokens[1].reference == "fox")
        #expect(alignment.tokens[1].heard == "box")
    }

    @Test
    func marksLowConfidenceMatchesBelowThreshold() {
        let alignment = TranscriptAlignment.align(
            reference: "red green blue",
            heard: [
                TranscriptToken("red", confidence: 0.9),
                TranscriptToken("green", confidence: 0.2),
                TranscriptToken("blue"),
            ],
            lowConfidenceThreshold: 0.5)
        #expect(alignment.tokens.map(\.status) == [.match, .lowConfidence, .match])
        #expect(alignment.tokens[1].confidence == 0.2)
    }

    @Test
    func splitsMultiWordTokensAndKeepsTheirConfidence() {
        let alignment = TranscriptAlignment.align(
            reference: "see you later",
            heard: [TranscriptToken("see you", confidence: 0.3), TranscriptToken("later")])
        #expect(alignment.tokens.map(\.status) == [.lowConfidence, .lowConfidence, .match])
    }

    @Test
    func scoresMatchesLowConfidenceAndInsertions() {
        let alignment = TranscriptAlignment(tokens: [
            AlignedToken(reference: "a", heard: "a", status: .match),
            AlignedToken(reference: "b", heard: "b", confidence: 0.1, status: .lowConfidence),
            AlignedToken(reference: "c", heard: "x", status: .substitution),
            AlignedToken(reference: "d", heard: nil, status: .omission),
            AlignedToken(reference: nil, heard: "e", status: .insertion),
        ])
        #expect(alignment.referenceWordCount == 4)
        #expect(alignment.count(of: .match) == 1)
        #expect(alignment.completeness == 0.75)
        #expect(alignment.score == 1.5 / 5)
    }

    @Test
    func emptyAlignmentIsCompleteAndPerfect() {
        let alignment = TranscriptAlignment.align(reference: "", heard: "")
        #expect(alignment.tokens.isEmpty)
        #expect(alignment.completeness == 1)
        #expect(alignment.score == 1)
    }

    @Test
    func recognizedWordConvertsToToken() {
        let word = RecognizedWord(text: "hi", confidence: 0.4, startTime: 1, duration: 0.2)
        #expect(word.transcriptToken == TranscriptToken("hi", confidence: 0.4))
    }
}

@Suite("EditDistance")
struct EditDistanceTests {
    @Test
    func prefersSubstitutionOverDeleteAndInsert() {
        #expect(EditDistance.operations(from: ["a"], to: ["b"]) == [.substitute(0, 0)])
    }

    @Test
    func handlesEmptySides() {
        #expect(EditDistance.operations(from: [], to: []) == [])
        #expect(EditDistance.operations(from: ["a", "b"], to: []) == [.delete(0), .delete(1)])
        #expect(EditDistance.operations(from: [], to: ["a"]) == [.insert(0)])
    }

    @Test
    func alignsAroundAMissingMiddleWord() {
        #expect(
            EditDistance.operations(from: ["a", "b", "c"], to: ["a", "c"]) == [
                .keep(0, 0), .delete(1), .keep(2, 1),
            ])
    }
}

@Suite("TranscriptNormalizer")
struct TranscriptNormalizerTests {
    @Test
    func splitsOnWhitespaceDashesAndSlashes() {
        #expect(
            TranscriptNormalizer.words(in: "  one two—three/four\nfive ")
                == ["one", "two", "three", "four", "five"])
    }

    @Test
    func stripsEdgePunctuationButKeepsInnerApostrophes() {
        #expect(TranscriptNormalizer.words(in: "\"It's 5 o’clock!\"") == ["It's", "5", "o'clock"])
        #expect(TranscriptNormalizer.words(in: "... !! ?") == [])
    }

    @Test
    func keyIsCaseFolded() {
        #expect(
            TranscriptNormalizer.key(for: "HeLLo", locale: Locale(identifier: "en_US")) == "hello")
    }
}
