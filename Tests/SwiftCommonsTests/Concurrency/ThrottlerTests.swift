import Foundation
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@Suite("Throttler")
struct ThrottlerTests {
    private actor Recorder {
        private(set) var values: [Int] = []
        func record(_ value: Int) {
            values.append(value)
        }

        /// Yields until `values` equals `expected`, giving up after a bounded number of turns.
        func waitForValues(_ expected: [Int]) async {
            var iterations = 0
            while values != expected, iterations < 1_000 {
                await Task.yield()
                iterations += 1
            }
        }
    }

    @Test
    func firstCallRunsImmediatelyWithoutAdvancingTheClock() async {
        let throttler = Throttler(interval: .seconds(1), clock: ManualClock())
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }

        #expect(await recorder.values == [1])
    }

    @Test
    func callsInsideTheIntervalCoalesceIntoOneTrailingRun() async throws {
        let clock = ManualClock()
        let throttler = Throttler(interval: .seconds(1), clock: clock)
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await throttler.run { await recorder.record(2) }
        await throttler.run { await recorder.record(3) }

        #expect(await recorder.values == [1])

        await clock.advance(by: .seconds(1))
        await recorder.waitForValues([1, 3])

        #expect(await recorder.values == [1, 3])
    }

    @Test
    func trailingRunOpensANewIntervalThatThrottlesLaterCalls() async throws {
        let clock = ManualClock()
        let throttler = Throttler(interval: .seconds(1), clock: clock)
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await throttler.run { await recorder.record(2) }
        await clock.advance(by: .seconds(1))
        await recorder.waitForValues([1, 2])
        try #require(await clock.waitForSleepCount(2))

        await throttler.run { await recorder.record(3) }
        #expect(await recorder.values == [1, 2])

        await clock.advance(by: .seconds(1))
        await recorder.waitForValues([1, 2, 3])
        #expect(await recorder.values == [1, 2, 3])
    }

    @Test
    func callRunsImmediatelyAgainOnceAnIntervalEndsWithNothingWaiting() async throws {
        let clock = ManualClock()
        let throttler = Throttler(interval: .seconds(1), clock: clock)
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await clock.advance(by: .seconds(1))
        while await clock.waiterCount > 0 { await Task.yield() }
        // Let the window task finish closing the interval.
        for _ in 0..<50 { await Task.yield() }

        await throttler.run { await recorder.record(2) }

        #expect(await recorder.values == [1, 2])
    }

    @Test
    func droppingTrailingCallsIgnoresCallsInsideTheInterval() async throws {
        let clock = ManualClock()
        let throttler = Throttler(interval: .seconds(1), runsTrailingCall: false, clock: clock)
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await throttler.run { await recorder.record(2) }
        await clock.advance(by: .seconds(1))
        for _ in 0..<50 { await Task.yield() }

        #expect(await recorder.values == [1])
    }

    @Test
    func cancelDropsTheWaitingCallAndReopensTheThrottler() async throws {
        let clock = ManualClock()
        let throttler = Throttler(interval: .seconds(1), clock: clock)
        let recorder = Recorder()

        await throttler.run { await recorder.record(1) }
        try #require(await clock.waitForSleepCount(1))
        await throttler.run { await recorder.record(2) }
        await throttler.cancel()

        await throttler.run { await recorder.record(3) }
        await clock.advance(by: .seconds(1))
        for _ in 0..<50 { await Task.yield() }

        #expect(await recorder.values == [1, 3])
    }
}
