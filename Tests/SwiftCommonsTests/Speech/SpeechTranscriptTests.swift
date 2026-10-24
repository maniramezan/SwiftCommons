import CoreMedia
import Foundation
import Speech
import Testing

@testable import SwiftCommonsSpeech

@Suite("SpeechTranscript")
struct SpeechTranscriptTests {
    @Test
    func joinsFinalizedAndVolatileText() {
        let transcript = SpeechTranscript(
            finalizedUtterances: [
                RecognizedUtterance(text: "Hello there.", words: [RecognizedWord(text: "Hello")]),
                RecognizedUtterance(text: " How are ", words: [RecognizedWord(text: "How")]),
            ],
            volatileText: "you")
        #expect(transcript.finalizedText == "Hello there. How are")
        #expect(transcript.text == "Hello there. How are you")
        #expect(transcript.words.map(\.text) == ["Hello", "How"])
        #expect(!transcript.isFinal)
    }

    @Test
    func emptyTranscriptIsFinal() {
        let transcript = SpeechTranscript()
        #expect(transcript.text.isEmpty)
        #expect(transcript.isFinal)
    }

    @Test
    func accumulatorReplacesVolatileAndAppendsFinals() {
        var accumulator = TranscriptAccumulator()
        #expect(accumulator.applyVolatile(text: "hel").text == "hel")
        #expect(accumulator.applyVolatile(text: "hello").text == "hello")
        let afterFinal = accumulator.applyFinal(RecognizedUtterance(text: "Hello", words: []))
        #expect(afterFinal.text == "Hello")
        #expect(afterFinal.isFinal)
        #expect(accumulator.applyVolatile(text: "world").text == "Hello world")
    }

    @Test
    func accumulatorDropsEmptyFinals() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.applyVolatile(text: "uh")
        let transcript = accumulator.applyFinal(RecognizedUtterance(text: "  ", words: []))
        #expect(transcript.finalizedUtterances.isEmpty)
        #expect(transcript.volatileText.isEmpty)
    }
}

@Suite("SpeechResultMapping")
struct SpeechResultMappingTests {
    @available(macOS 26, iOS 26, macCatalyst 26, *)
    private func word(_ text: String, confidence: Double?, start: Double?, duration: Double = 0.5)
        -> AttributedString
    {
        var string = AttributedString(text)
        if let confidence {
            string[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self] = confidence
        }
        if let start {
            string[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] = CMTimeRange(
                start: CMTime(seconds: start, preferredTimescale: 600),
                duration: CMTime(seconds: duration, preferredTimescale: 600))
        }
        return string
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func mapsPerWordRunsWithConfidenceAndTiming() throws {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        var text = word("Hello", confidence: 0.9, start: 0)
        text += AttributedString(" ")
        text += word("world", confidence: 0.4, start: 0.6)
        let utterance = SpeechResultMapping.utterance(
            from: text,
            alternatives: [AttributedString("Hello world"), AttributedString("Yellow world ")])

        #expect(utterance.text == "Hello world")
        #expect(utterance.words.map(\.text) == ["Hello", "world"])
        #expect(utterance.words.map(\.confidence) == [0.9, 0.4])
        let start = try #require(utterance.words[1].startTime)
        #expect(abs(start - 0.6) < 0.01)
        let duration = try #require(utterance.words[1].duration)
        #expect(abs(duration - 0.5) < 0.01)
        #expect(utterance.alternatives == ["Yellow world"])
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func splitsMultiWordRunsWithoutTiming() {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        let utterance = SpeechResultMapping.utterance(
            from: word("good morning", confidence: 0.7, start: 0))
        #expect(utterance.words.map(\.text) == ["good", "morning"])
        #expect(utterance.words.map(\.confidence) == [0.7, 0.7])
        #expect(utterance.words.allSatisfy { $0.startTime == nil })
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func ignoresInvalidTimeRanges() {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        var text = AttributedString("hi")
        text[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] = .invalid
        let utterance = SpeechResultMapping.utterance(from: text)
        #expect(utterance.words.first?.startTime == nil)
        #expect(utterance.words.first?.confidence == nil)
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func reportingOptionsFollowConfiguration() {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        let locale = Locale(identifier: "en_US")
        #expect(
            SpeechRecognitionSession.reportingOptions(
                for: SpeechRecognitionConfiguration(locale: locale))
                == [.volatileResults, .alternativeTranscriptions])
        #expect(
            SpeechRecognitionSession.reportingOptions(
                for: SpeechRecognitionConfiguration(
                    locale: locale, reportsAlternatives: false, prefersFastResults: true))
                == [.volatileResults, .fastResults])
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func idleSessionStopAndCancelAreNoOps() async {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        let session = SpeechRecognitionSession()
        await session.stop()
        await session.cancel()
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func modelAssetStatusMapping() {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        #expect(SpeechModelAssets.status(for: AssetInventory.Status.unsupported) == .unsupported)
        #expect(SpeechModelAssets.status(for: AssetInventory.Status.supported) == .notInstalled)
        #expect(SpeechModelAssets.status(for: AssetInventory.Status.downloading) == .downloading)
        #expect(SpeechModelAssets.status(for: AssetInventory.Status.installed) == .installed)
    }
}

enum SpeechTestAvailability {
    static var hasSpeechAnalyzer: Bool {
        if #available(macOS 26, iOS 26, macCatalyst 26, *) { return true }
        return false
    }
}
