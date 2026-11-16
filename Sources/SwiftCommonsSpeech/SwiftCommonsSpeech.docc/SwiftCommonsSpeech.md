# ``SwiftCommonsSpeech``

On-device speech-to-text, text-to-speech, and read-aloud transcript alignment.

## Overview

SwiftCommonsSpeech wraps Apple's on-device `SpeechAnalyzer` and `AVSpeechSynthesizer` behind small
protocols (``SpeechRecognizing`` and ``SpeechSynthesizing``) so features can be tested with fakes.
It is a separate product from `SwiftCommons`, so apps that don't use speech don't link `Speech` or
`AVFAudio`. The live APIs need iOS 26 or macOS 26; everything else follows the package minimums.

```swift
import SwiftCommonsSpeech

guard await SpeechRecognitionPermissions.requestAll() else { return }
let locale = Locale(identifier: "en_US")
if await SpeechModelAssets.status(for: locale) != .installed {
    try await SpeechModelAssets.install(for: locale) { progress in print(progress) }
}

let recognizer = SpeechRecognitionSession()
let events = try await recognizer.start(
    SpeechRecognitionConfiguration(locale: locale, autoStopAfterSilence: .seconds(1.5)))
var transcript = SpeechTranscript()
for try await event in events {
    if case .transcript(let latest) = event { transcript = latest }
}

let alignment = TranscriptAlignment.align(
    reference: "The quick brown fox", heard: transcript.words.map(\.transcriptToken))
```

### Grading a read-aloud attempt

``TranscriptAlignment`` compares what the recognizer *understood* against a reference text. It
catches missed, extra, and misheard words, but a recognizer often repairs mildly mispronounced
words, so it isn't phoneme-level pronunciation scoring. Leave
``SpeechRecognitionConfiguration`` contextual strings empty when grading, or the recognizer is
biased toward the expected sentence.

### Audio sessions

The sessions don't configure `AVAudioSession`. On iOS, activate `.playAndRecord` (or `.playback`
for speech output only) before starting recognition or speaking.

## Topics

### Recognition

- ``SpeechRecognizing``
- ``SpeechRecognitionSession``
- ``SpeechRecognitionConfiguration``
- ``SpeechRecognitionEvent``
- ``SpeechRecognitionError``
- ``SpeechTranscript``
- ``RecognizedUtterance``
- ``RecognizedWord``

### Models and permissions

- ``SpeechModelAssets``
- ``SpeechRecognitionPermissions``
- ``SpeechPermissionStatus``

### Synthesis

- ``SpeechSynthesizing``
- ``SpeechSynthesisSession``
- ``SpeechSynthesisRequest``
- ``SpeechSynthesisEvent``
- ``SpeechVoice``

### Alignment

- ``TranscriptAlignment``
- ``TranscriptToken``
- ``AlignedToken``
- ``AlignedTokenStatus``

### Diagnostics

- ``SpeechLogging``
