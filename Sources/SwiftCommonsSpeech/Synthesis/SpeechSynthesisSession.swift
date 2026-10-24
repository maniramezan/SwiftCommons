import AVFAudio
import Foundation
import Synchronization

/// On-device text-to-speech built on `AVSpeechSynthesizer`.
///
///     let speech = SpeechSynthesisSession()
///     for await event in speech.speak(SpeechSynthesisRequest(text: reply, languageCode: "en-US")) {
///         if case .started = event { indicator.isHidden = false }
///     }
///
/// It's main-actor isolated because it drives UI-facing playback and is created and called from
/// view models; the synthesizer's delegate callbacks are routed to each request's stream without
/// needing the main actor.
///
/// **Audio session:** on iOS, speech plays through the app's `AVAudioSession`. Configure a
/// playback-capable category before speaking; if the app also records, use `.playAndRecord`.
@MainActor
public final class SpeechSynthesisSession: NSObject, SpeechSynthesizing {
    private let synthesizer = AVSpeechSynthesizer()
    private let router = SynthesisEventRouter()
    private let installedVoices: @MainActor () -> [SpeechVoice]

    /// Creates a session.
    /// - Parameter installedVoices: Supplies the voices to choose from; defaults to the device's
    ///   installed voices.
    public init(
        installedVoices: @escaping @MainActor () -> [SpeechVoice] = {
            SpeechVoice.installedVoices()
        }
    ) {
        self.installedVoices = installedVoices
        super.init()
        synthesizer.delegate = self
    }

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    var routerForTesting: SynthesisEventRouter {
        router
    }

    public func speak(
        _ request: SpeechSynthesisRequest, interrupting: Bool = true
    ) -> AsyncStream<SpeechSynthesisEvent> {
        if interrupting && synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = Self.utterance(for: request, installedVoices: installedVoices())
        let events = router.register(ObjectIdentifier(utterance))
        SpeechLogging.synthesis.info(
            "Speaking length=\(request.text.count) language=\(request.languageCode)")
        synthesizer.speak(utterance)
        return events
    }

    public func stopSpeaking() {
        SpeechLogging.synthesis.info("Stopping speech")
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Builds the utterance for a request, resolving its voice.
    static func utterance(
        for request: SpeechSynthesisRequest, installedVoices: [SpeechVoice]
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: request.text)
        let voiceID =
            request.voiceID.flatMap { id in installedVoices.first { $0.id == id }?.id }
            ?? SpeechVoice.best(for: request.languageCode, among: installedVoices)?.id
        utterance.voice =
            voiceID.flatMap(AVSpeechSynthesisVoice.init(identifier:))
            ?? AVSpeechSynthesisVoice(language: request.languageCode)
        if let rate = request.rate {
            utterance.rate =
                AVSpeechUtteranceMinimumSpeechRate
                + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
                * min(max(rate, 0), 1)
        }
        utterance.pitchMultiplier = min(max(request.pitch, 0.5), 2)
        return utterance
    }
}

extension SpeechSynthesisSession: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance
    ) {
        router.send(.started, to: ObjectIdentifier(utterance))
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        guard let range = Range(characterRange) else { return }
        router.send(.willSpeak(range), to: ObjectIdentifier(utterance))
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        router.send(.finished, to: ObjectIdentifier(utterance))
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        router.send(.cancelled, to: ObjectIdentifier(utterance))
    }
}

/// Routes synthesizer delegate callbacks, which arrive on an arbitrary thread, to the stream of
/// the utterance they belong to.
final class SynthesisEventRouter: Sendable {
    private let continuations = Mutex<
        [ObjectIdentifier: AsyncStream<SpeechSynthesisEvent>.Continuation]
    >(
        [:])

    /// Opens the event stream for an utterance.
    func register(_ id: ObjectIdentifier) -> AsyncStream<SpeechSynthesisEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SpeechSynthesisEvent.self)
        continuations.withLock { $0[id] = continuation }
        return stream
    }

    /// Delivers an event; ``SpeechSynthesisEvent/finished`` and ``SpeechSynthesisEvent/cancelled``
    /// also end the stream. Events for unknown utterances are ignored.
    func send(_ event: SpeechSynthesisEvent, to id: ObjectIdentifier) {
        let isTerminal = event == .finished || event == .cancelled
        let continuation = continuations.withLock { table in
            isTerminal ? table.removeValue(forKey: id) : table[id]
        }
        continuation?.yield(event)
        if isTerminal {
            continuation?.finish()
        }
    }

    /// The number of utterances with an open stream.
    var openStreamCount: Int {
        continuations.withLock { $0.count }
    }
}
