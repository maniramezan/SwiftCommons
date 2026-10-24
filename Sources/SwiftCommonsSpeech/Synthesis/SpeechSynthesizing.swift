import Foundation

/// Text to speak and how to speak it.
public struct SpeechSynthesisRequest: Sendable, Hashable {
    /// The text to speak.
    public var text: String
    /// The BCP 47 language of the text, such as `en-US`. Used to pick a voice when ``voiceID`` is
    /// `nil` or not installed.
    public var languageCode: String
    /// A specific ``SpeechVoice/id`` to use, or `nil` for the best installed voice for
    /// ``languageCode``.
    public var voiceID: String?
    /// The speaking rate from `0` (slowest) to `1` (fastest), or `nil` for the system default.
    public var rate: Float?
    /// The pitch multiplier, from `0.5` to `2`.
    public var pitch: Float

    /// Creates a request.
    public init(
        text: String, languageCode: String, voiceID: String? = nil, rate: Float? = nil,
        pitch: Float = 1
    ) {
        self.text = text
        self.languageCode = languageCode
        self.voiceID = voiceID
        self.rate = rate
        self.pitch = pitch
    }
}

/// Progress of one spoken request.
public enum SpeechSynthesisEvent: Sendable, Hashable {
    /// Audio started playing.
    case started
    /// The synthesizer is about to speak this range of the text, in UTF-16 offsets, for
    /// highlighting along with the speech.
    case willSpeak(Range<Int>)
    /// Speech finished normally. The stream ends after this event.
    case finished
    /// Speech was stopped before it finished. The stream ends after this event.
    case cancelled
}

/// Speaks text aloud.
///
/// ``SpeechSynthesisSession`` is the on-device implementation. Depend on this protocol so tests,
/// previews, or a server-backed voice can substitute for it.
@MainActor
public protocol SpeechSynthesizing: AnyObject {
    /// Whether speech is playing.
    var isSpeaking: Bool { get }

    /// Speaks `request` and returns its progress. The stream ends with
    /// ``SpeechSynthesisEvent/finished`` or ``SpeechSynthesisEvent/cancelled``.
    /// - Parameter interrupting: Stops current speech first when `true`; queues after it when
    ///   `false`.
    func speak(_ request: SpeechSynthesisRequest, interrupting: Bool) -> AsyncStream<
        SpeechSynthesisEvent
    >

    /// Stops all current and queued speech.
    func stopSpeaking()
}
