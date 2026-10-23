import Foundation

/// One word in a recognized utterance, with the recognizer's confidence and timing when reported.
public struct RecognizedWord: Sendable, Hashable {
    /// The word as the recognizer wrote it.
    public var text: String
    /// The recognizer's confidence from `0` to `1`, or `nil` when it didn't report one.
    public var confidence: Double?
    /// When the word starts, in seconds from the start of the recording, if reported.
    public var startTime: TimeInterval?
    /// How long the word lasts, in seconds, if reported.
    public var duration: TimeInterval?

    /// Creates a recognized word.
    public init(
        text: String, confidence: Double? = nil, startTime: TimeInterval? = nil,
        duration: TimeInterval? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.startTime = startTime
        self.duration = duration
    }

    /// The word as input for ``TranscriptAlignment/align(reference:heard:lowConfidenceThreshold:locale:)``.
    public var transcriptToken: TranscriptToken {
        TranscriptToken(text, confidence: confidence)
    }
}

/// A finalized stretch of recognized speech.
///
/// A recognizer finalizes speech in segments as it becomes confident about them; one recording
/// usually yields one or more utterances.
public struct RecognizedUtterance: Sendable, Hashable {
    /// The recognized text.
    public var text: String
    /// The words in ``text``, with confidence and timing when the recognizer reported them.
    public var words: [RecognizedWord]
    /// Other plausible transcriptions, most likely first, excluding ``text``.
    public var alternatives: [String]

    /// Creates an utterance.
    public init(text: String, words: [RecognizedWord], alternatives: [String] = []) {
        self.text = text
        self.words = words
        self.alternatives = alternatives
    }
}

/// Everything recognized so far in one recognition run.
///
/// ``finalizedUtterances`` won't change again. ``volatileText`` is the recognizer's current guess
/// at speech it hasn't finalized yet, and is replaced by each update, so show it as a preview.
public struct SpeechTranscript: Sendable, Hashable {
    /// Utterances the recognizer has finalized, in order.
    public var finalizedUtterances: [RecognizedUtterance]
    /// The recognizer's current guess at not-yet-final speech; empty when nothing is pending.
    public var volatileText: String

    /// Creates a transcript.
    public init(finalizedUtterances: [RecognizedUtterance] = [], volatileText: String = "") {
        self.finalizedUtterances = finalizedUtterances
        self.volatileText = volatileText
    }

    /// The finalized text, without the volatile preview.
    public var finalizedText: String {
        Self.join(finalizedUtterances.map(\.text))
    }

    /// The finalized text followed by the volatile preview.
    public var text: String {
        Self.join(finalizedUtterances.map(\.text) + [volatileText])
    }

    /// Every finalized word, in order.
    public var words: [RecognizedWord] {
        finalizedUtterances.flatMap(\.words)
    }

    /// Whether nothing is pending finalization.
    public var isFinal: Bool {
        volatileText.isEmpty
    }

    private static func join(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Builds a ``SpeechTranscript`` from a recognizer's stream of volatile and final results.
struct TranscriptAccumulator {
    private(set) var transcript = SpeechTranscript()

    /// Records a volatile (preview) result, replacing the previous preview.
    mutating func applyVolatile(text: String) -> SpeechTranscript {
        transcript.volatileText = text
        return transcript
    }

    /// Records a final result and clears the preview it replaces.
    mutating func applyFinal(_ utterance: RecognizedUtterance) -> SpeechTranscript {
        if !utterance.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            transcript.finalizedUtterances.append(utterance)
        }
        transcript.volatileText = ""
        return transcript
    }
}
