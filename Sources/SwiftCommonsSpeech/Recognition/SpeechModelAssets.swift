import Foundation
import Speech

/// Checks for and installs the on-device speech-recognition model for a locale.
///
/// Models are downloaded by the system on request and shared between apps. Install one before
/// starting a ``SpeechRecognitionSession`` for its locale:
///
///     if await SpeechModelAssets.status(for: locale) != .installed {
///         try await SpeechModelAssets.install(for: locale) { progress in meter.value = progress }
///     }
@available(macOS 26, iOS 26, macCatalyst 26, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public enum SpeechModelAssets {
    /// Whether a locale's model is available.
    public enum Status: Sendable, Hashable, CaseIterable {
        /// On-device recognition doesn't support the locale.
        case unsupported
        /// The model is supported but not downloaded.
        case notInstalled
        /// The model is downloading.
        case downloading
        /// The model is ready to use.
        case installed
    }

    /// Locales that on-device recognition supports, whether or not their model is installed.
    public static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales
    }

    /// The model status for `locale`, matched to the closest supported locale.
    public static func status(for locale: Locale) async -> Status {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return .unsupported
        }
        return status(for: await AssetInventory.status(forModules: [transcriber(for: supported)]))
    }

    /// Downloads and installs the model for `locale` if needed, reporting progress from `0` to
    /// `1`.
    ///
    /// - Throws: ``SpeechRecognitionError/unsupportedLocale(_:)`` when the locale isn't supported,
    ///   or the system's download error.
    public static func install(
        for locale: Locale, progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpeechRecognitionError.unsupportedLocale(locale.identifier)
        }
        let modules: [any SpeechModule] = [transcriber(for: supported)]
        guard let request = try await AssetInventory.assetInstallationRequest(supporting: modules)
        else {
            SpeechLogging.assets.info("Model already installed locale=\(supported.identifier)")
            progress?(1)
            return
        }
        SpeechLogging.assets.info("Installing model locale=\(supported.identifier)")
        let reporter = Task {
            while !Task.isCancelled {
                progress?(request.progress.fractionCompleted)
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { reporter.cancel() }
        do {
            try await request.downloadAndInstall()
        } catch {
            SpeechLogging.assets.error(
                "Model install failed locale=\(supported.identifier)", error: error)
            throw error
        }
        progress?(1)
        SpeechLogging.assets.info("Model installed locale=\(supported.identifier)")
    }

    static func status(for status: AssetInventory.Status) -> Status {
        switch status {
        case .unsupported: .unsupported
        case .supported: .notInstalled
        case .downloading: .downloading
        case .installed: .installed
        @unknown default: .unsupported
        }
    }

    private static func transcriber(for locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale, transcriptionOptions: [], reportingOptions: [],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence])
    }
}
