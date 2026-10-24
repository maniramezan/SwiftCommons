import AVFAudio
import Foundation

/// Converts microphone samples into a `0...1` loudness level suitable for a level meter.
enum AudioLevelMeter {
    /// Levels at or below this many decibels (full scale) read as silence.
    static let floorDecibels: Float = -50

    /// The normalized RMS level of `samples`: `0` at or below ``floorDecibels``, `1` at full
    /// scale.
    static func level(of samples: UnsafeBufferPointer<Float>) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sumOfSquares: Float = 0
        for sample in samples {
            sumOfSquares += sample * sample
        }
        let rms = (sumOfSquares / Float(samples.count)).squareRoot()
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        let normalized = (decibels - floorDecibels) / -floorDecibels
        return Double(min(max(normalized, 0), 1))
    }

    /// The normalized level of the first channel of a float PCM buffer, or `0` for other formats.
    static func level(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        return level(of: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

/// Decides when a speaker has finished, from a stream of audio levels.
///
/// The monitor waits until it hears speech (a level at or above ``speechThreshold``), then fires
/// once the level has stayed below the threshold for ``timeout``. It fires at most once.
struct SilenceMonitor {
    let speechThreshold: Double
    let timeout: Duration

    private(set) var hasHeardSpeech = false
    private(set) var hasFired = false
    private var silenceStart: ContinuousClock.Instant?

    init(speechThreshold: Double = 0.3, timeout: Duration) {
        self.speechThreshold = speechThreshold
        self.timeout = timeout
    }

    /// Records a level observed at `instant` and returns `true` the first time silence has lasted
    /// ``timeout`` after speech.
    mutating func observe(level: Double, at instant: ContinuousClock.Instant) -> Bool {
        guard !hasFired else { return false }
        if level >= speechThreshold {
            hasHeardSpeech = true
            silenceStart = nil
            return false
        }
        guard hasHeardSpeech else { return false }
        guard let start = silenceStart else {
            silenceStart = instant
            return false
        }
        if instant - start >= timeout {
            hasFired = true
            return true
        }
        return false
    }
}
