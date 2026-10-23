import SwiftCommons

/// The level-gated logger shared by SwiftCommonsSpeech.
///
/// It logs warnings and errors by default. Raise the level to trace recognition and synthesis:
///
///     SpeechLogging.logger.setLevel(.debug)
///
/// Messages never include transcript text or synthesized speech, only lengths, locales, and state.
public enum SpeechLogging {
    /// The logger for the `SwiftCommonsSpeech` subsystem.
    public static let logger = LibraryLogger(subsystem: "SwiftCommonsSpeech")

    static let recognition = logger.category("recognition")
    static let synthesis = logger.category("synthesis")
    static let assets = logger.category("assets")
}
