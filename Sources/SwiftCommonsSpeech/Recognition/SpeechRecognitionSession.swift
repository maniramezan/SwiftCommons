import AVFAudio
import Foundation
import Speech

/// On-device speech recognition from the microphone, built on `SpeechAnalyzer` and
/// `SpeechTranscriber`.
///
///     let session = SpeechRecognitionSession()
///     let events = try await session.start(
///         SpeechRecognitionConfiguration(locale: Locale(identifier: "en_US"),
///                                        autoStopAfterSilence: .seconds(1.5)))
///     for try await event in events {
///         if case .transcript(let transcript) = event { label.text = transcript.text }
///     }
///
/// Before starting, request permission with ``SpeechRecognitionPermissions`` and install the
/// locale's model with ``SpeechModelAssets``. Otherwise ``start(_:)`` throws
/// ``SpeechRecognitionError/modelNotInstalled(_:)``.
///
/// **Audio session:** on iOS, the session doesn't configure `AVAudioSession`. Activate a
/// recording-capable category (for example `.playAndRecord`) before calling ``start(_:)``.
///
/// One session runs one recognition at a time; reuse it for the next run after the previous
/// event stream finishes.
@available(macOS 26, iOS 26, macCatalyst 26, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public actor SpeechRecognitionSession: SpeechRecognizing {
    private struct Run {
        let engine: AVAudioEngine
        let analyzer: SpeechAnalyzer
        let input: AsyncStream<AnalyzerInput>.Continuation
        let processor: AudioTapProcessor
        let results: Task<Void, Never>
    }

    private enum State {
        case idle
        case starting
        case running(Run)
    }

    private var state = State.idle

    /// Creates an idle session.
    public init() {}

    public func start(
        _ configuration: SpeechRecognitionConfiguration
    ) async throws -> AsyncThrowingStream<SpeechRecognitionEvent, any Error> {
        guard case .idle = state else { throw SpeechRecognitionError.alreadyRunning }
        state = .starting
        SpeechLogging.recognition.info(
            "Starting recognition locale=\(configuration.locale.identifier)")
        do {
            let (run, events) = try await makeRun(configuration)
            state = .running(run)
            SpeechLogging.recognition.info("Recognition started")
            return events
        } catch {
            state = .idle
            SpeechLogging.recognition.error("Recognition failed to start", error: error)
            throw error
        }
    }

    public func stop() async {
        guard case .running(let run) = state else { return }
        state = .idle
        SpeechLogging.recognition.info("Stopping recognition")
        Self.stopAudio(run)
        run.input.finish()
        do {
            try await run.analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            SpeechLogging.recognition.error("Finalizing failed; cancelling", error: error)
            await run.analyzer.cancelAndFinishNow()
        }
        await run.results.value
        SpeechLogging.recognition.info("Recognition stopped")
    }

    public func cancel() async {
        guard case .running(let run) = state else { return }
        state = .idle
        SpeechLogging.recognition.info("Cancelling recognition")
        Self.stopAudio(run)
        run.input.finish()
        await run.analyzer.cancelAndFinishNow()
        await run.results.value
        SpeechLogging.recognition.info("Recognition cancelled")
    }

    // MARK: - Setup

    private func makeRun(
        _ configuration: SpeechRecognitionConfiguration
    ) async throws -> (Run, AsyncThrowingStream<SpeechRecognitionEvent, any Error>) {
        guard
            let locale = await SpeechTranscriber.supportedLocale(
                equivalentTo: configuration.locale)
        else {
            throw SpeechRecognitionError.unsupportedLocale(configuration.locale.identifier)
        }
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: Self.reportingOptions(for: configuration),
            attributeOptions: [.audioTimeRange, .transcriptionConfidence])
        let modules: [any SpeechModule] = [transcriber]
        guard await AssetInventory.status(forModules: modules) == .installed else {
            throw SpeechRecognitionError.modelNotInstalled(locale.identifier)
        }

        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
            let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                compatibleWith: modules, considering: inputFormat)
        else {
            throw SpeechRecognitionError.incompatibleAudioFormat
        }

        let analyzer = SpeechAnalyzer(modules: modules)
        if !configuration.contextualStrings.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = configuration.contextualStrings
            try await analyzer.setContext(context)
        }
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let (inputStream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        let (events, eventSink) = AsyncThrowingStream.makeStream(
            of: SpeechRecognitionEvent.self, bufferingPolicy: .bufferingNewest(64))
        let processor = try AudioTapProcessor(
            inputFormat: inputFormat,
            outputFormat: analyzerFormat,
            recordingURL: configuration.recordingURL,
            silenceMonitor: configuration.autoStopAfterSilence.map {
                SilenceMonitor(speechThreshold: configuration.speechLevelThreshold, timeout: $0)
            },
            onLevel: { eventSink.yield(.audioLevel($0)) },
            onConverted: { input.yield(AnalyzerInput(buffer: $0)) },
            onSilence: { [weak self] in
                SpeechLogging.recognition.info("Silence detected; auto-stopping")
                eventSink.yield(.silenceDetected)
                Task { await self?.stop() }
            })

        Self.installTap(on: engine.inputNode, format: inputFormat, processor: processor)
        do {
            engine.prepare()
            try engine.start()
            try await analyzer.start(inputSequence: inputStream)
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            processor.close()
            input.finish()
            await analyzer.cancelAndFinishNow()
            throw error
        }

        let results = Task {
            var accumulator = TranscriptAccumulator()
            do {
                for try await result in transcriber.results {
                    let transcript =
                        result.isFinal
                        ? accumulator.applyFinal(
                            SpeechResultMapping.utterance(
                                from: result.text, alternatives: result.alternatives))
                        : accumulator.applyVolatile(text: String(result.text.characters))
                    eventSink.yield(.transcript(transcript))
                }
                eventSink.finish()
            } catch {
                SpeechLogging.recognition.error("Transcriber results failed", error: error)
                eventSink.finish(throwing: error)
            }
        }
        eventSink.onTermination = { [weak self] termination in
            guard case .cancelled = termination else { return }
            Task { await self?.cancel() }
        }
        eventSink.yield(.ready)
        return (
            Run(
                engine: engine, analyzer: analyzer, input: input, processor: processor,
                results: results),
            events
        )
    }

    static func reportingOptions(
        for configuration: SpeechRecognitionConfiguration
    ) -> Set<SpeechTranscriber.ReportingOption> {
        var options: Set<SpeechTranscriber.ReportingOption> = [.volatileResults]
        if configuration.reportsAlternatives {
            options.insert(.alternativeTranscriptions)
        }
        if configuration.prefersFastResults {
            options.insert(.fastResults)
        }
        return options
    }

    /// Installs the tap from a nonisolated context so the tap block isn't actor-isolated: the
    /// engine calls it on its own audio thread.
    private nonisolated static func installTap(
        on node: AVAudioInputNode, format: AVAudioFormat, processor: AudioTapProcessor
    ) {
        node.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            processor.process(buffer)
        }
    }

    private static func stopAudio(_ run: Run) {
        run.engine.inputNode.removeTap(onBus: 0)
        run.engine.stop()
        run.processor.close()
    }
}
