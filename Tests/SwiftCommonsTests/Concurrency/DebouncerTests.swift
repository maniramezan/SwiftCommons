import Foundation
import Testing

@testable import SwiftCommons

@Suite("Debouncer")
struct DebouncerTests {
    private actor Recorder {
        private(set) var values: [Int] = []
        func record(_ value: Int) {
            values.append(value)
        }
    }

    @Test
    func onlyRunsTheLastActionWithinTheDelayWindow() async {
        let debouncer = Debouncer(delay: .milliseconds(50))
        let recorder = Recorder()

        for value in 1...5 {
            await debouncer.run { await recorder.record(value) }
        }

        try? await Task.sleep(for: .milliseconds(200))
        #expect(await recorder.values == [5])
    }

    @Test
    func runsAgainAfterThePreviousActionCompletes() async {
        let debouncer = Debouncer(delay: .milliseconds(20))
        let recorder = Recorder()

        await debouncer.run { await recorder.record(1) }
        try? await Task.sleep(for: .milliseconds(100))

        await debouncer.run { await recorder.record(2) }
        try? await Task.sleep(for: .milliseconds(100))

        #expect(await recorder.values == [1, 2])
    }

    @Test
    func cancelPreventsThePendingActionFromRunning() async {
        let debouncer = Debouncer(delay: .milliseconds(30))
        let recorder = Recorder()

        await debouncer.run { await recorder.record(1) }
        await debouncer.cancel()

        try? await Task.sleep(for: .milliseconds(100))
        #expect(await recorder.values == [])
    }
}
