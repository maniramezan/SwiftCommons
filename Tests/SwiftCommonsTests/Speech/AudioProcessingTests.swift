import AVFAudio
import Foundation
import Synchronization
import Testing

@testable import SwiftCommonsSpeech

private func sineBuffer(
    format: AVAudioFormat, frames: AVAudioFrameCount, amplitude: Float
) throws -> AVAudioPCMBuffer {
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
    buffer.frameLength = frames
    let channel = try #require(buffer.floatChannelData?[0])
    for index in 0..<Int(frames) {
        channel[index] = amplitude * sin(Float(index) * 2 * .pi * 440 / Float(format.sampleRate))
    }
    return buffer
}

private func monoFloat(_ sampleRate: Double) throws -> AVAudioFormat {
    try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
}

private final class Recorder: Sendable {
    let levels = Mutex<[Double]>([])
    let convertedFrames = Mutex<[AVAudioFrameCount]>([])
    let silences = Mutex(0)

    var levelSnapshot: [Double] { levels.withLock { $0 } }
    var convertedSnapshot: [AVAudioFrameCount] { convertedFrames.withLock { $0 } }
    var silenceCount: Int { silences.withLock { $0 } }
}

@Suite("AudioLevelMeter")
struct AudioLevelMeterTests {
    @Test
    func silenceIsZeroAndFullScaleIsOne() throws {
        let format = try monoFloat(16_000)
        #expect(
            AudioLevelMeter.level(of: try sineBuffer(format: format, frames: 1600, amplitude: 0))
                == 0)
        let loud = AudioLevelMeter.level(
            of: try sineBuffer(format: format, frames: 1600, amplitude: 1))
        #expect(loud > 0.9)
    }

    @Test
    func quieterAudioReadsLower() throws {
        let format = try monoFloat(16_000)
        let quiet = AudioLevelMeter.level(
            of: try sineBuffer(format: format, frames: 1600, amplitude: 0.01))
        let normal = AudioLevelMeter.level(
            of: try sineBuffer(format: format, frames: 1600, amplitude: 0.3))
        #expect(quiet < normal)
        #expect(quiet >= 0)
    }

    @Test
    func emptySamplesReadAsSilence() {
        #expect(AudioLevelMeter.level(of: UnsafeBufferPointer<Float>(start: nil, count: 0)) == 0)
    }

    @Test
    func nonFloatBuffersReadAsSilence() throws {
        let format = try #require(
            AVAudioFormat(
                commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 10))
        buffer.frameLength = 10
        #expect(AudioLevelMeter.level(of: buffer) == 0)
    }
}

@Suite("SilenceMonitor")
struct SilenceMonitorTests {
    /// Feeds `(milliseconds, level)` samples and returns which ones fired.
    private func fired(
        _ monitor: inout SilenceMonitor, _ samples: [(Int, Double)]
    ) -> [Bool] {
        let start = ContinuousClock.now
        return samples.map { offset, level in
            monitor.observe(level: level, at: start + .milliseconds(offset))
        }
    }

    @Test
    func firesOnceAfterSilenceFollowingSpeech() {
        var monitor = SilenceMonitor(speechThreshold: 0.3, timeout: .seconds(1))
        let quietStart = fired(&monitor, [(0, 0.1)])
        #expect(quietStart == [false])
        #expect(!monitor.hasHeardSpeech)

        let results = fired(
            &monitor, [(100, 0.5), (200, 0.1), (900, 0.1), (1200, 0.1), (5000, 0.1)])
        #expect(results == [false, false, false, true, false])
        #expect(monitor.hasHeardSpeech)
        #expect(monitor.hasFired)
    }

    @Test
    func speechResetsTheSilenceTimer() {
        var monitor = SilenceMonitor(timeout: .seconds(1))
        let results = fired(
            &monitor, [(0, 0.9), (100, 0), (900, 0.9), (1000, 0), (1500, 0), (2000, 0)])
        #expect(results == [false, false, false, false, false, true])
    }

    @Test
    func neverFiresWithoutSpeech() {
        var monitor = SilenceMonitor(timeout: .milliseconds(10))
        let results = fired(&monitor, (0..<10).map { ($0 * 1000, 0) })
        #expect(!results.contains(true))
    }
}

@Suite("AudioTapProcessor")
struct AudioTapProcessorTests {
    private func makeProcessor(
        input: AVAudioFormat, output: AVAudioFormat, recordingURL: URL? = nil,
        silence: SilenceMonitor? = nil, recorder: Recorder
    ) throws -> AudioTapProcessor {
        try AudioTapProcessor(
            inputFormat: input, outputFormat: output, recordingURL: recordingURL,
            silenceMonitor: silence,
            onLevel: { level in recorder.levels.withLock { $0.append(level) } },
            onConverted: { buffer in
                let frames = buffer.frameLength
                recorder.convertedFrames.withLock { $0.append(frames) }
            },
            onSilence: { recorder.silences.withLock { $0 += 1 } })
    }

    @Test
    func passesThroughMatchingFormats() throws {
        let format = try monoFloat(16_000)
        let recorder = Recorder()
        let processor = try makeProcessor(input: format, output: format, recorder: recorder)
        processor.process(try sineBuffer(format: format, frames: 1600, amplitude: 0.5))
        #expect(recorder.convertedSnapshot == [1600])
        #expect(recorder.levelSnapshot.count == 1)
    }

    @Test
    func resamplesToTheOutputFormat() throws {
        let recorder = Recorder()
        let processor = try makeProcessor(
            input: try monoFloat(48_000), output: try monoFloat(16_000), recorder: recorder)
        for _ in 0..<4 {
            processor.process(
                try sineBuffer(format: try monoFloat(48_000), frames: 4800, amplitude: 0.5))
        }
        let frames = recorder.convertedSnapshot
        #expect(!frames.isEmpty)
        let total = frames.reduce(0, +)
        #expect(total > 4800 && total <= 6400)
    }

    @Test
    func recordsInputToFile() throws {
        let format = try monoFloat(16_000)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tap-\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = Recorder()
        let processor = try makeProcessor(
            input: format, output: format, recordingURL: url, recorder: recorder)
        processor.process(try sineBuffer(format: format, frames: 1600, amplitude: 0.5))
        processor.process(try sineBuffer(format: format, frames: 1600, amplitude: 0.5))
        processor.close()

        let file = try AVAudioFile(forReading: url)
        #expect(file.length == 3200)
    }

    @Test
    func reportsSilenceAfterSpeech() throws {
        let format = try monoFloat(16_000)
        let recorder = Recorder()
        let processor = try makeProcessor(
            input: format, output: format,
            silence: SilenceMonitor(speechThreshold: 0.3, timeout: .milliseconds(500)),
            recorder: recorder)
        let start = ContinuousClock.now
        processor.process(try sineBuffer(format: format, frames: 160, amplitude: 0.8), at: start)
        processor.process(
            try sineBuffer(format: format, frames: 160, amplitude: 0),
            at: start + .milliseconds(100))
        processor.process(
            try sineBuffer(format: format, frames: 160, amplitude: 0),
            at: start + .milliseconds(700))
        #expect(recorder.silenceCount == 1)
    }

    @Test
    func ignoresBuffersAfterClose() throws {
        let format = try monoFloat(16_000)
        let recorder = Recorder()
        let processor = try makeProcessor(input: format, output: format, recorder: recorder)
        processor.close()
        processor.process(try sineBuffer(format: format, frames: 160, amplitude: 0.5))
        #expect(recorder.levelSnapshot.isEmpty)
        #expect(recorder.convertedSnapshot.isEmpty)
    }
}
