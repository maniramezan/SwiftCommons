import AVFAudio
import Foundation

/// A text-to-speech voice installed on the device.
public struct SpeechVoice: Sendable, Hashable, Identifiable {
    /// How natural a voice sounds. Higher-quality voices are larger downloads the user installs
    /// in Settings.
    public enum Quality: Int, Sendable, Hashable, Comparable, CaseIterable {
        /// The compact voice every device has.
        case standard
        /// An enhanced voice.
        case enhanced
        /// A premium (neural) voice.
        case premium

        public static func < (lhs: Quality, rhs: Quality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The system voice identifier.
    public let id: String
    /// The voice's display name.
    public let name: String
    /// The BCP 47 language code, such as `en-US`.
    public let languageCode: String
    /// The voice's quality tier.
    public let quality: Quality

    /// Creates a voice description.
    public init(id: String, name: String, languageCode: String, quality: Quality) {
        self.id = id
        self.name = name
        self.languageCode = languageCode
        self.quality = quality
    }

    /// Every installed voice, sorted by language, then best quality first, then name.
    public static func installedVoices() -> [SpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices().map(SpeechVoice.init(_:)).sorted {
            ($0.languageCode, $1.quality, $0.name) < ($1.languageCode, $0.quality, $1.name)
        }
    }

    /// The best voice for a language among `voices`.
    ///
    /// An exact language match (`en-US`) beats a same-language match in another region (`en-GB`).
    /// Within each group, higher ``quality`` wins, then name order.
    /// - Returns: `nil` when no voice speaks the language.
    public static func best(
        for languageCode: String, among voices: [SpeechVoice] = installedVoices()
    ) -> SpeechVoice? {
        let wanted = normalized(languageCode)
        let wantedLanguage = baseLanguage(wanted)
        let candidates = voices.filter {
            baseLanguage(normalized($0.languageCode)) == wantedLanguage
        }
        return candidates.min { lhs, rhs in
            let lhsExact = normalized(lhs.languageCode) == wanted
            let rhsExact = normalized(rhs.languageCode) == wanted
            if lhsExact != rhsExact { return lhsExact }
            if lhs.quality != rhs.quality { return lhs.quality > rhs.quality }
            return lhs.name < rhs.name
        }
    }

    init(_ voice: AVSpeechSynthesisVoice) {
        let quality: Quality =
            switch voice.quality {
            case .premium: .premium
            case .enhanced: .enhanced
            default: .standard
            }
        self.init(
            id: voice.identifier, name: voice.name, languageCode: voice.language, quality: quality)
    }

    private static func normalized(_ code: String) -> String {
        code.replacing("_", with: "-").lowercased()
    }

    private static func baseLanguage(_ code: String) -> Substring {
        code.split(separator: "-").first ?? Substring(code)
    }
}
