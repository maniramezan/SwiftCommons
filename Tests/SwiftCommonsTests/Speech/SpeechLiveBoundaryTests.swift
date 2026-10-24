import Foundation
import Testing

@testable import SwiftCommonsSpeech

/// Exercises the live adapters' early-exit paths, which need no microphone or model download.
@Suite("Speech live boundaries")
struct SpeechLiveBoundaryTests {
    private let unsupported = Locale(identifier: "zz_ZZ")

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func startRejectsUnsupportedLocaleAndStaysReusable() async {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        let session = SpeechRecognitionSession()
        let configuration = SpeechRecognitionConfiguration(locale: unsupported)
        await #expect(throws: SpeechRecognitionError.unsupportedLocale("zz_ZZ")) {
            _ = try await session.start(configuration)
        }
        await #expect(throws: SpeechRecognitionError.unsupportedLocale("zz_ZZ")) {
            _ = try await session.start(configuration)
        }
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func assetQueriesHandleUnsupportedLocales() async {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        #expect(await SpeechModelAssets.status(for: unsupported) == .unsupported)
        await #expect(throws: SpeechRecognitionError.unsupportedLocale("zz_ZZ")) {
            try await SpeechModelAssets.install(for: unsupported)
        }
        let supported = await SpeechModelAssets.supportedLocales()
        #expect(!supported.contains(unsupported))
    }

    @Test(.enabled(if: SpeechTestAvailability.hasSpeechAnalyzer))
    func assetStatusForSupportedLocalesIsNeverUnsupported() async {
        guard #available(macOS 26, iOS 26, macCatalyst 26, *) else { return }
        let supported = await SpeechModelAssets.supportedLocales()
        for locale in supported {
            #expect(await SpeechModelAssets.status(for: locale) != .unsupported)
        }
    }
}
