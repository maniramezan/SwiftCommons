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
    func onlyRunsTheLastActionWithinTheDelayWindow() async throws {
        let clock = ManualClock()
        let debouncer = Debouncer(delay: .milliseconds(50), clock: clock)
        let recorder = Recorder()

        for value in 1...5 {
            await debouncer.run { await recorder.record(value) }
            try #require(await clock.waitForSleepCount(value))
        }

        // Superseded sleeps are removed on cancellation; every action has registered
        // before we advance, so the final action cannot miss the virtual deadline.
        await clock.advance(by: .milliseconds(50))

        var iterations = 0
        while await recorder.values != [5], iterations < 1_000 {
            await Task.yield()
            iterations += 1
        }

        #expect(await recorder.values == [5])
    }

    @Test
    func runsAgainAfterThePreviousActionCompletes() async {
        let clock = ManualClock()
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
    func cancelPreventsThePendingActionFromRunning() async throws {
        let clock = ManualClock()
        let debouncer = Debouncer(delay: .milliseconds(30), clock: clock)
        let recorder = Recorder()

        await debouncer.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await debouncer.cancel()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await clock.waiterCount > 0, ContinuousClock.now < deadline { await Task.yield() }
        #expect(await clock.waiterCount == 0)

        #expect(await recorder.values == [])
    }

    @Test
    func deallocatingTheDebouncerCancelsThePendingAction() async {
        let clock = ManualClock()
        let recorder = Recorder()
        var debouncer: Debouncer? = Debouncer(delay: .milliseconds(30), clock: clock)

        await debouncer?.run { await recorder.record(1) }
        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        debouncer = nil

        await clock.advance(by: .milliseconds(30))
        await Task.yield()

        #expect(debouncer == nil)
        #expect(await recorder.values == [])
    }
}
