import Foundation
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

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
        let clock = ManualSwiftCommonsClock()
        let debouncer = Debouncer(delay: .milliseconds(50), clock: clock)
        let recorder = Recorder()

        for value in 1...5 {
            await debouncer.run { await recorder.record(value) }
        }

        // Every call (including the four superseded ones) reaches its
        // `clock.sleep(for:)` and registers a waiter; only the last one's
        // action actually runs once resumed, since `Debouncer` checks
        // `Task.isCancelled` before invoking it. Wait for all five to
        // register before advancing so none are missed.
        while await clock.waiterCount < 5 {
            await Task.yield()
        }
        await clock.advance(by: .milliseconds(50))
        await Task.yield()

        #expect(await recorder.values == [5])
    }

    @Test
    func runsAgainAfterThePreviousActionCompletes() async {
        let clock = ManualSwiftCommonsClock()
        let debouncer = Debouncer(delay: .milliseconds(20), clock: clock)
        let recorder = Recorder()

        await debouncer.run { await recorder.record(1) }
        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        await clock.advance(by: .milliseconds(20))
        await Task.yield()

        await debouncer.run { await recorder.record(2) }
        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        await clock.advance(by: .milliseconds(20))
        await Task.yield()

        #expect(await recorder.values == [1, 2])
    }

    @Test
    func cancelPreventsThePendingActionFromRunning() async {
        let clock = ManualSwiftCommonsClock()
        let debouncer = Debouncer(delay: .milliseconds(30), clock: clock)
        let recorder = Recorder()

        await debouncer.run { await recorder.record(1) }
        await debouncer.cancel()

        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        await clock.advance(by: .milliseconds(30))
        await Task.yield()

        #expect(await recorder.values == [])
    }
}
