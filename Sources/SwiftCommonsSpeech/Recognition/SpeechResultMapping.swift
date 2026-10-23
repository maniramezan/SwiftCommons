import CoreMedia
import Foundation
import Speech

@available(macOS 26, iOS 26, macCatalyst 26, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
enum SpeechResultMapping {
    /// Converts a transcriber result's attributed text into an utterance.
    ///
    /// The transcriber attaches confidence and audio time-range attributes to runs of the text,
    /// usually one run per word. A run that spans several words gives each the run's confidence
    /// and no timing, since the run's time range can't be split reliably.
    static func utterance(
        from text: AttributedString, alternatives: [AttributedString] = []
    ) -> RecognizedUtterance {
        var words: [RecognizedWord] = []
        for run in text.runs {
            let runText = String(text[run.range].characters)
            let parts = runText.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !parts.isEmpty else { continue }
            let confidence = run[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self]
            let timeRange = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self]
            if parts.count == 1 {
                words.append(
                    RecognizedWord(
                        text: parts[0], confidence: confidence,
                        startTime: timeRange.flatMap { seconds($0.start) },
                        duration: timeRange.flatMap { seconds($0.duration) }))
            } else {
                words += parts.map { RecognizedWord(text: $0, confidence: confidence) }
            }
        }
        let plain = String(text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        let others = alternatives.map {
            String($0.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return RecognizedUtterance(
            text: plain, words: words,
            alternatives: others.filter { !$0.isEmpty && $0 != plain })
    }

    private static func seconds(_ time: CMTime) -> TimeInterval? {
        guard time.isValid, time.isNumeric else { return nil }
        return time.seconds
    }
}
