import Foundation

/// A word heard by a speech recognizer, with the recognizer's confidence in it when known.
///
/// This is the input side of ``TranscriptAlignment``. Build it from any recognizer's output;
/// ``RecognizedWord`` converts to it with ``RecognizedWord/transcriptToken``.
public struct TranscriptToken: Sendable, Hashable {
    /// The word as the recognizer wrote it.
    public var text: String
    /// The recognizer's confidence in the word, from `0` to `1`, or `nil` when it didn't report
    /// one.
    public var confidence: Double?

    /// Creates a heard word.
    /// - Parameters:
    ///   - text: The word as the recognizer wrote it.
    ///   - confidence: The recognizer's confidence from `0` to `1`, or `nil` if unknown.
    public init(_ text: String, confidence: Double? = nil) {
        self.text = text
        self.confidence = confidence
    }
}

/// How one position of a ``TranscriptAlignment`` compares the expected text with what was heard.
public enum AlignedTokenStatus: Sendable, Hashable, CaseIterable {
    /// The expected word was heard, with confidence at or above the threshold (or unknown).
    case match
    /// The expected word was heard, but the recognizer's confidence was below the threshold.
    case lowConfidence
    /// A different word was heard in place of the expected one.
    case substitution
    /// The expected word wasn't heard.
    case omission
    /// A word was heard that the expected text doesn't contain.
    case insertion
}

/// One position in a ``TranscriptAlignment``: an expected word, a heard word, or both.
public struct AlignedToken: Sendable, Hashable {
    /// The expected word, as written in the reference text. `nil` for an
    /// ``AlignedTokenStatus/insertion``.
    public let reference: String?
    /// The heard word, as the recognizer wrote it. `nil` for an
    /// ``AlignedTokenStatus/omission``.
    public let heard: String?
    /// The recognizer's confidence in ``heard``, when it reported one.
    public let confidence: Double?
    /// How the expected and heard words compare.
    public let status: AlignedTokenStatus

    /// Creates an aligned position.
    public init(
        reference: String?, heard: String?, confidence: Double? = nil, status: AlignedTokenStatus
    ) {
        self.reference = reference
        self.heard = heard
        self.confidence = confidence
        self.status = status
    }
}

/// A word-level comparison between the text someone was asked to say and what a speech recognizer
/// heard.
///
/// Use it for read-aloud exercises: show the reference sentence, record the speaker, and align the
/// transcript against the sentence to find matched, misheard, missed, and extra words:
///
///     let alignment = TranscriptAlignment.align(
///         reference: "The quick brown fox",
///         heard: [TranscriptToken("the"), TranscriptToken("quick"), TranscriptToken("box")]
///     )
///     alignment.tokens.map(\.status)  // [.match, .match, .omission, .substitution]
///
/// Words are compared after normalization (case-folded, punctuation stripped, curly apostrophes
/// straightened, hyphenated words split), so `"Don’t"` matches `"don't"`. Numbers aren't spelled
/// out, so a recognizer that writes `"3"` for a spoken "three" counts as a substitution.
///
/// The alignment is a minimum-edit-distance alignment over words, so a single missed word doesn't
/// shift every following word into a mismatch. It measures what the recognizer understood, not
/// pronunciation itself. A recognizer's language model often repairs mildly mispronounced words,
/// so treat a clean alignment as "intelligible", not "perfect".
public struct TranscriptAlignment: Sendable, Hashable {
    /// Every aligned position, in reading order.
    public let tokens: [AlignedToken]

    /// The number of words in the reference text.
    public var referenceWordCount: Int {
        tokens.count { $0.reference != nil }
    }

    /// The number of positions with the given status.
    public func count(of status: AlignedTokenStatus) -> Int {
        tokens.count { $0.status == status }
    }

    /// The share of reference words that were heard at all (matched, low-confidence, or
    /// substituted), from `0` to `1`. An empty reference counts as complete.
    public var completeness: Double {
        let total = referenceWordCount
        guard total > 0 else { return 1 }
        return Double(total - count(of: .omission)) / Double(total)
    }

    /// An overall score from `0` to `1`.
    ///
    /// Each ``AlignedTokenStatus/match`` earns one point and each
    /// ``AlignedTokenStatus/lowConfidence`` earns half a point. The total is divided by the number
    /// of reference words plus the number of inserted words, so extra words lower the score.
    /// An empty reference with nothing heard scores `1`.
    public var score: Double {
        let denominator = referenceWordCount + count(of: .insertion)
        guard denominator > 0 else { return 1 }
        let points = Double(count(of: .match)) + Double(count(of: .lowConfidence)) * 0.5
        return points / Double(denominator)
    }

    /// Creates an alignment from precomputed positions.
    public init(tokens: [AlignedToken]) {
        self.tokens = tokens
    }

    /// Aligns heard words against a reference text.
    ///
    /// - Parameters:
    ///   - reference: The text the speaker was asked to say.
    ///   - heard: The words the recognizer heard, in order.
    ///   - lowConfidenceThreshold: Matched words whose confidence is below this become
    ///     ``AlignedTokenStatus/lowConfidence``. Words without a confidence are never low.
    ///   - locale: The locale used for case folding.
    public static func align(
        reference: String,
        heard: [TranscriptToken],
        lowConfidenceThreshold: Double = 0.5,
        locale: Locale = Locale(identifier: "en_US")
    ) -> TranscriptAlignment {
        let referenceWords = TranscriptNormalizer.words(in: reference)
        let heardWords = heard.flatMap { token in
            TranscriptNormalizer.words(in: token.text).map {
                TranscriptToken($0, confidence: token.confidence)
            }
        }
        let referenceKeys = referenceWords.map { TranscriptNormalizer.key(for: $0, locale: locale) }
        let heardKeys = heardWords.map { TranscriptNormalizer.key(for: $0.text, locale: locale) }

        let operations = EditDistance.operations(from: referenceKeys, to: heardKeys)
        let tokens = operations.map { operation -> AlignedToken in
            switch operation {
            case .keep(let r, let h):
                let word = heardWords[h]
                let isLow = word.confidence.map { $0 < lowConfidenceThreshold } ?? false
                return AlignedToken(
                    reference: referenceWords[r], heard: word.text, confidence: word.confidence,
                    status: isLow ? .lowConfidence : .match)
            case .substitute(let r, let h):
                let word = heardWords[h]
                return AlignedToken(
                    reference: referenceWords[r], heard: word.text, confidence: word.confidence,
                    status: .substitution)
            case .delete(let r):
                return AlignedToken(reference: referenceWords[r], heard: nil, status: .omission)
            case .insert(let h):
                let word = heardWords[h]
                return AlignedToken(
                    reference: nil, heard: word.text, confidence: word.confidence,
                    status: .insertion)
            }
        }
        return TranscriptAlignment(tokens: tokens)
    }

    /// Aligns a plain heard transcript, with no confidences, against a reference text.
    public static func align(
        reference: String,
        heard: String,
        locale: Locale = Locale(identifier: "en_US")
    ) -> TranscriptAlignment {
        align(reference: reference, heard: [TranscriptToken(heard)], locale: locale)
    }
}
