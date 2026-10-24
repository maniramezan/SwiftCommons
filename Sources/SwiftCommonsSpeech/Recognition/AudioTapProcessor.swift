import AVFAudio
import Foundation
import Synchronization

/// Handles each microphone buffer from an audio-engine tap: meters it, records it, converts it to
/// the recognizer's format, and watches for end-of-speech silence.
///
/// The tap calls ``process(_:at:)`` on the audio thread. All mutable state (converter, recording
/// file, silence monitor) lives in a `Mutex`, so a late callback racing ``close()`` is safe.
final class AudioTapProcessor: Sendable {
    private struct State {
        var converter: AVAudioConverter?
        var recording: AVAudioFile?
        var silenceMonitor: SilenceMonitor?
        var isClosed = false
    }

    private let state: Mutex<State>
    private let outputFormat: AVAudioFormat
    private let onLevel: @Sendable (Double) -> Void
    private let onConverted: @Sendable (AVAudioPCMBuffer) -> Void
    private let onSilence: @Sendable () -> Void

    /// Creates a processor.
    /// - Parameters:
    ///   - inputFormat: The tap's buffer format.
    ///   - outputFormat: The format the recognizer expects.
    ///   - recordingURL: Where to write the unconverted input, or `nil` to record nothing.
    ///   - silenceMonitor: End-of-speech detection, or `nil` to disable it.
    ///   - onLevel: Receives each buffer's `0...1` level.
    ///   - onConverted: Receives each buffer converted to `outputFormat`.
    ///   - onSilence: Called once when `silenceMonitor` fires.
    init(
        inputFormat: AVAudioFormat,
        outputFormat: AVAudioFormat,
        recordingURL: URL?,
        silenceMonitor: SilenceMonitor?,
        onLevel: @escaping @Sendable (Double) -> Void,
        onConverted: @escaping @Sendable (AVAudioPCMBuffer) -> Void,
        onSilence: @escaping @Sendable () -> Void
    ) throws {
        let converter =
            inputFormat == outputFormat
            ? nil : AVAudioConverter(from: inputFormat, to: outputFormat)
        if inputFormat != outputFormat && converter == nil {
            throw SpeechRecognitionError.incompatibleAudioFormat
        }
        var recording: AVAudioFile?
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            recording = try AVAudioFile(
                forWriting: recordingURL, settings: inputFormat.settings,
                commonFormat: inputFormat.commonFormat, interleaved: inputFormat.isInterleaved)
        }
        self.state = Mutex(
            State(converter: converter, recording: recording, silenceMonitor: silenceMonitor))
        self.outputFormat = outputFormat
        self.onLevel = onLevel
        self.onConverted = onConverted
        self.onSilence = onSilence
    }

    /// Processes one tap buffer. Does nothing after ``close()``.
    func process(_ buffer: AVAudioPCMBuffer, at instant: ContinuousClock.Instant = .now) {
        let level = AudioLevelMeter.level(of: buffer)
        // The callbacks only yield to stream continuations, so running them under the lock is
        // cheap, and it keeps the converted buffer from crossing out of the locked region.
        state.withLock { state in
            guard !state.isClosed else { return }
            do {
                try state.recording?.write(from: buffer)
            } catch {
                SpeechLogging.recognition.error(
                    "Recording write failed; recording stops", error: error)
                state.recording = nil
            }
            let silent = state.silenceMonitor?.observe(level: level, at: instant) ?? false
            onLevel(level)
            if let converter = state.converter {
                if let converted = Self.convert(buffer, with: converter, to: outputFormat) {
                    onConverted(converted)
                }
            } else {
                onConverted(buffer)
            }
            if silent {
                onSilence()
            }
        }
    }

    /// Stops processing and closes the recording file.
    func close() {
        state.withLock { state in
            state.isClosed = true
            state.recording = nil
            state.converter = nil
        }
    }

    /// Converts one buffer with a sample-rate/format converter, or returns `nil` on failure.
    static func convert(
        _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            return nil
        }
        let feed = SingleBufferFeed(buffer)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            feed.next(inputStatus)
        }
        guard status != .error, conversionError == nil, output.frameLength > 0 else {
            return nil
        }
        return output
    }
}

/// Supplies one buffer to an `AVAudioConverter` input block, then reports "no data now" so the
/// converter keeps its state for the next tap buffer.
///
/// The converter calls the input block synchronously, inside `convert(to:error:withInputFrom:)`,
/// on the calling thread, so the unsynchronized flag is never touched concurrently.
private final class SingleBufferFeed: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private var isConsumed = false

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard !isConsumed else {
            status.pointee = .noDataNow
            return nil
        }
        isConsumed = true
        status.pointee = .haveData
        return buffer
    }
}
