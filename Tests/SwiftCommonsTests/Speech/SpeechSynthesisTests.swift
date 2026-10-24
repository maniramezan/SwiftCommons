import AVFAudio
import Foundation
import Speech
import Testing

@testable import SwiftCommonsSpeech

@Suite("SpeechVoice")
struct SpeechVoiceTests {
    private let voices = [
        SpeechVoice(id: "gb-premium", name: "Ava", languageCode: "en-GB", quality: .premium),
        SpeechVoice(id: "us-standard", name: "Fred", languageCode: "en-US", quality: .standard),
        SpeechVoice(id: "us-enhanced-b", name: "Zoe", languageCode: "en-US", quality: .enhanced),
        SpeechVoice(id: "us-enhanced-a", name: "Alex", languageCode: "en-US", quality: .enhanced),
        SpeechVoice(id: "fr", name: "Amélie", languageCode: "fr-FR", quality: .premium),
    ]

    @Test
    func prefersExactRegionThenQualityThenName() {
        #expect(SpeechVoice.best(for: "en-US", among: voices)?.id == "us-enhanced-a")
        #expect(SpeechVoice.best(for: "en_us", among: voices)?.id == "us-enhanced-a")
    }

    @Test
    func fallsBackToSameLanguageInAnotherRegion() {
        #expect(SpeechVoice.best(for: "en-AU", among: voices)?.id == "gb-premium")
        #expect(SpeechVoice.best(for: "fr", among: voices)?.id == "fr")
    }

    @Test
    func returnsNilForUnknownLanguage() {
        #expect(SpeechVoice.best(for: "ja-JP", among: voices) == nil)
    }

    @Test
    func qualityIsOrdered() {
        #expect(SpeechVoice.Quality.standard < .enhanced)
        #expect(SpeechVoice.Quality.enhanced < .premium)
    }

    @Test
    func installedVoicesAreSortedByLanguageThenQuality() {
        let installed = SpeechVoice.installedVoices()
        for (lhs, rhs) in zip(installed, installed.dropFirst())
        where lhs.languageCode == rhs.languageCode {
            #expect(lhs.quality >= rhs.quality)
        }
    }
}

@Suite("SpeechSynthesisSession")
@MainActor
struct SpeechSynthesisSessionTests {
    private let voices = SpeechVoice.installedVoices()

    @Test
    func mapsRateAndClampsPitch() {
        let slow = SpeechSynthesisSession.utterance(
            for: SpeechSynthesisRequest(text: "hi", languageCode: "en-US", rate: 0, pitch: 5),
            installedVoices: voices)
        #expect(slow.rate == AVSpeechUtteranceMinimumSpeechRate)
        #expect(slow.pitchMultiplier == 2)

        let fast = SpeechSynthesisSession.utterance(
            for: SpeechSynthesisRequest(text: "hi", languageCode: "en-US", rate: 3, pitch: 0),
            installedVoices: voices)
        #expect(fast.rate == AVSpeechUtteranceMaximumSpeechRate)
        #expect(fast.pitchMultiplier == 0.5)

        let normal = SpeechSynthesisSession.utterance(
            for: SpeechSynthesisRequest(text: "hi", languageCode: "en-US"), installedVoices: voices)
        #expect(normal.rate == AVSpeechUtteranceDefaultSpeechRate)
    }

    @Test
    func usesRequestedVoiceWhenInstalled() throws {
        let voice = try #require(voices.first)
        let utterance = SpeechSynthesisSession.utterance(
            for: SpeechSynthesisRequest(text: "hi", languageCode: "xx", voiceID: voice.id),
            installedVoices: voices)
        #expect(utterance.voice?.identifier == voice.id)
    }

    @Test
    func fallsBackToBestVoiceForLanguage() throws {
        let english = try #require(SpeechVoice.best(for: "en-US", among: voices))
        let utterance = SpeechSynthesisSession.utterance(
            for: SpeechSynthesisRequest(text: "hi", languageCode: "en-US", voiceID: "missing"),
            installedVoices: voices)
        #expect(utterance.voice?.identifier == english.id)
    }

    @Test
    func stoppingWhenIdleIsSafe() {
        let session = SpeechSynthesisSession(installedVoices: { [] })
        #expect(!session.isSpeaking)
        session.stopSpeaking()
    }

    @Test
    func delegateCallbacksReachTheUtteranceStream() async {
        let session = SpeechSynthesisSession(installedVoices: { [] })
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: "hello")
        let events = session.routerForTesting.register(ObjectIdentifier(utterance))
        session.speechSynthesizer(synthesizer, didStart: utterance)
        session.speechSynthesizer(
            synthesizer, willSpeakRangeOfSpeechString: NSRange(location: 0, length: 5),
            utterance: utterance)
        session.speechSynthesizer(
            synthesizer, willSpeakRangeOfSpeechString: NSRange(location: NSNotFound, length: 0),
            utterance: utterance)
        session.speechSynthesizer(synthesizer, didFinish: utterance)

        var received: [SpeechSynthesisEvent] = []
        for await event in events {
            received.append(event)
        }
        #expect(received == [.started, .willSpeak(0..<5), .finished])
    }

    @Test
    func cancelCallbackEndsTheStream() async {
        let session = SpeechSynthesisSession(installedVoices: { [] })
        let utterance = AVSpeechUtterance(string: "hello")
        let events = session.routerForTesting.register(ObjectIdentifier(utterance))
        session.speechSynthesizer(AVSpeechSynthesizer(), didCancel: utterance)
        var received: [SpeechSynthesisEvent] = []
        for await event in events {
            received.append(event)
        }
        #expect(received == [.cancelled])
    }
}

@Suite("SynthesisEventRouter")
struct SynthesisEventRouterTests {
    private final class Token {}

    @Test
    func routesEventsUntilTerminal() async {
        let router = SynthesisEventRouter()
        let token = Token()
        let id = ObjectIdentifier(token)
        let stream = router.register(id)
        #expect(router.openStreamCount == 1)
        router.send(.started, to: id)
        router.send(.finished, to: id)
        router.send(.started, to: id)
        #expect(router.openStreamCount == 0)

        var received: [SpeechSynthesisEvent] = []
        for await event in stream {
            received.append(event)
        }
        #expect(received == [.started, .finished])
        withExtendedLifetime(token) {}
    }

    @Test
    func ignoresUnknownUtterances() {
        let router = SynthesisEventRouter()
        let token = Token()
        router.send(.cancelled, to: ObjectIdentifier(token))
        #expect(router.openStreamCount == 0)
    }
}

@Suite("SpeechRecognitionPermissions")
struct SpeechRecognitionPermissionsTests {
    @Test
    func mapsMicrophonePermission() {
        #expect(
            SpeechRecognitionPermissions.status(for: AVAudioApplication.recordPermission.granted)
                == .authorized)
        #expect(
            SpeechRecognitionPermissions.status(for: AVAudioApplication.recordPermission.denied)
                == .denied)
        #expect(
            SpeechRecognitionPermissions.status(
                for: AVAudioApplication.recordPermission.undetermined) == .notDetermined)
    }

    @Test
    func mapsSpeechRecognitionAuthorization() {
        #expect(
            SpeechRecognitionPermissions.status(
                for: SFSpeechRecognizerAuthorizationStatus.authorized) == .authorized)
        #expect(
            SpeechRecognitionPermissions.status(for: SFSpeechRecognizerAuthorizationStatus.denied)
                == .denied)
        #expect(
            SpeechRecognitionPermissions.status(
                for: SFSpeechRecognizerAuthorizationStatus.restricted) == .restricted)
        #expect(
            SpeechRecognitionPermissions.status(
                for: SFSpeechRecognizerAuthorizationStatus.notDetermined)
                == .notDetermined)
    }

    @Test
    func currentStatusesAreReadable() {
        let microphone = SpeechRecognitionPermissions.microphoneStatus
        let speech = SpeechRecognitionPermissions.speechRecognitionStatus
        #expect(
            SpeechRecognitionPermissions.isAuthorized
                == (microphone == .authorized && speech == .authorized))
    }
}

@Suite("SpeechRecognitionConfiguration")
struct SpeechRecognitionConfigurationTests {
    @Test
    func defaultsFavorUnbiasedAccurateRecognition() {
        let configuration = SpeechRecognitionConfiguration(locale: Locale(identifier: "en_US"))
        #expect(configuration.contextualStrings.isEmpty)
        #expect(configuration.reportsAlternatives)
        #expect(!configuration.prefersFastResults)
        #expect(configuration.autoStopAfterSilence == nil)
        #expect(configuration.speechLevelThreshold == 0.3)
        #expect(configuration.recordingURL == nil)
    }
}
