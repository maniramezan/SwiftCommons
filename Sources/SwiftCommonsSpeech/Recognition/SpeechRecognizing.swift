import Foundation

/// Options for one recognition run.
public struct SpeechRecognitionConfiguration: Sendable, Hashable {
    /// The language to recognize. The recognizer uses the closest supported locale.
    public var locale: Locale
    /// Phrases to bias recognition toward, such as names or domain terms.
    ///
    /// Leave this empty when grading a speaker against a known sentence: biasing toward the
    /// sentence makes the recognizer "hear" it even when it wasn't said clearly.
    public var contextualStrings: [String]
    /// Whether to report alternative transcriptions with each finalized utterance.
    public var reportsAlternatives: Bool
    /// Whether to trade some accuracy for lower latency in volatile and final results.
    public var prefersFastResults: Bool
    /// Stops recognition automatically once the speaker has been silent this long after speaking.
    /// `nil` keeps listening until ``SpeechRecognizing/stop()`` is called.
    public var autoStopAfterSilence: Duration?
    /// The `0...1` level at or above which audio counts as speech for
    /// ``autoStopAfterSilence``.
    public var speechLevelThreshold: Double
    /// Where to save the microphone audio as a file, for playback or later analysis. `nil` saves
    /// nothing. An existing file at the URL is replaced.
    public var recordingURL: URL?

    /// Creates a configuration.
    public init(
        locale: Locale,
        contextualStrings: [String] = [],
        reportsAlternatives: Bool = true,
        prefersFastResults: Bool = false,
        autoStopAfterSilence: Duration? = nil,
        speechLevelThreshold: Double = 0.3,
        recordingURL: URL? = nil
    ) {
        self.locale = locale
        self.contextualStrings = contextualStrings
        self.reportsAlternatives = reportsAlternatives
        self.prefersFastResults = prefersFastResults
        self.autoStopAfterSilence = autoStopAfterSilence
        self.speechLevelThreshold = speechLevelThreshold
        self.recordingURL = recordingURL
    }
}

/// Something that happened during a recognition run.
public enum SpeechRecognitionEvent: Sendable, Hashable {
    /// The microphone is live and the recognizer is listening.
    case ready
    /// The latest microphone level, from `0` (silence) to `1` (full scale). Arrives many times a
    /// second.
    case audioLevel(Double)
    /// The transcript changed: a new volatile preview or a newly finalized utterance.
    case transcript(SpeechTranscript)
    /// The speaker went quiet for ``SpeechRecognitionConfiguration/autoStopAfterSilence``, and
    /// the run is stopping. A final ``transcript(_:)`` may still follow.
    case silenceDetected
}

/// Why a recognition run couldn't start or failed.
public enum SpeechRecognitionError: Error, Sendable, Hashable {
    /// A run is already in progress; stop it first.
    case alreadyRunning
    /// On-device recognition doesn't support the requested locale.
    case unsupportedLocale(String)
    /// The recognition model for the locale isn't installed. Install it with
    /// ``SpeechModelAssets/install(for:progress:)``.
    case modelNotInstalled(String)
    /// The microphone's format can't be converted to one the recognizer accepts.
    case incompatibleAudioFormat
    /// Microphone or speech-recognition permission hasn't been granted.
    case notAuthorized
}

/// Recognizes speech from the microphone and reports a live transcript.
///
/// ``SpeechRecognitionSession`` is the on-device implementation. Depend on this protocol so tests
/// and previews can substitute a fake.
public protocol SpeechRecognizing: AnyObject, Sendable {
    /// Starts listening and returns the run's events.
    ///
    /// The stream finishes after ``stop()`` (or a silence auto-stop) once the last result is
    /// finalized, and throws if recognition fails. Cancelling iteration of the stream stops the
    /// run.
    func start(
        _ configuration: SpeechRecognitionConfiguration
    ) async throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error>

    /// Stops listening, finalizes pending speech, and waits for the event stream to finish.
    /// Does nothing when no run is in progress.
    func stop() async

    /// Stops listening immediately and discards pending speech.
    func cancel() async
}
