import AVFAudio
import Foundation
import Speech

/// The state of a privacy permission.
public enum SpeechPermissionStatus: Sendable, Hashable, CaseIterable {
    /// The user hasn't been asked yet.
    case notDetermined
    /// The user declined.
    case denied
    /// The device restricts the permission, for example through parental controls.
    case restricted
    /// The user granted it.
    case authorized
}

/// Reads and requests the microphone and speech-recognition permissions that recognition needs.
///
/// The app's Info.plist must contain `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription`, or the system terminates the app when asking.
public enum SpeechRecognitionPermissions {
    /// The current microphone permission.
    public static var microphoneStatus: SpeechPermissionStatus {
        status(for: AVAudioApplication.shared.recordPermission)
    }

    /// The current speech-recognition permission.
    public static var speechRecognitionStatus: SpeechPermissionStatus {
        status(for: SFSpeechRecognizer.authorizationStatus())
    }

    /// Whether both permissions are granted.
    public static var isAuthorized: Bool {
        microphoneStatus == .authorized && speechRecognitionStatus == .authorized
    }

    /// Asks for microphone access if needed and returns the resulting status.
    public static func requestMicrophone() async -> SpeechPermissionStatus {
        let granted = await AVAudioApplication.requestRecordPermission()
        SpeechLogging.recognition.info("Microphone permission granted=\(granted)")
        return granted ? .authorized : microphoneStatus
    }

    /// Asks for speech-recognition access if needed and returns the resulting status.
    public static func requestSpeechRecognition() async -> SpeechPermissionStatus {
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        let result = status(for: authorization)
        SpeechLogging.recognition.info("Speech recognition permission status=\(result)")
        return result
    }

    /// Asks for both permissions, microphone first, and returns whether both were granted.
    public static func requestAll() async -> Bool {
        guard await requestMicrophone() == .authorized else { return false }
        return await requestSpeechRecognition() == .authorized
    }

    static func status(for permission: AVAudioApplication.recordPermission)
        -> SpeechPermissionStatus
    {
        switch permission {
        case .granted: .authorized
        case .denied: .denied
        case .undetermined: .notDetermined
        @unknown default: .denied
        }
    }

    static func status(for authorization: SFSpeechRecognizerAuthorizationStatus)
        -> SpeechPermissionStatus
    {
        switch authorization {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }
}
