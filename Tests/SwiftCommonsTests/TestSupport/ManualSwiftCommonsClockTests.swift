import Foundation
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@Suite("ManualSwiftCommonsClock")
@MainActor
struct ManualSwiftCommonsClockTests {
    @Test
    func sleepSuspendsUntilAdvancedPastDuration() async {
        let clock = ManualSwiftCommonsClock()
        let finished = Box(false)

        let task = Task {
            try await clock.sleep(for: .seconds(1))
            await MainActor.run { finished.value = true }
        }

        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        #expect(!finished.value)

        await clock.advance(by: .milliseconds(500))
        await Task.yield()
        #expect(!finished.value)

        await clock.advance(by: .milliseconds(500))
        _ = try? await task.value
        #expect(finished.value)
    }

    @Test
    func sleepForZeroDurationReturnsImmediately() async throws {
        let clock = ManualSwiftCommonsClock()
        try await clock.sleep(for: .zero)
        // No advance() call needed — reaching this line proves it didn't hang.
    }

    @Test
    func withRetryUsesManualClockWithoutRealDelay() async throws {
        let clock = ManualSwiftCommonsClock()
        let attempts = Box(0)

        let task = Task {
            try await withRetry(attempts: 3, delay: .seconds(10), clock: clock) {
                let count = await MainActor.run { () -> Int in
                    attempts.value += 1
                    return attempts.value
                }
                if count < 3 {
                    struct Failure: Error {}
                    throw Failure()
                }
                return count
            }
        }

        // Drive the fake clock forward as each retry registers its sleep,
        // instead of waiting on real 10s delays.
        for _ in 0..<2 {
            while await clock.waiterCount == 0 {
                await Task.yield()
            }
            await clock.advance(by: .seconds(10))
        }

        let result = try await task.value
        #expect(result == 3)
        #expect(attempts.value == 3)
    }

    @Test
    func debouncerUsesManualClockWithoutRealDelay() async {
        let clock = ManualSwiftCommonsClock()
        let debouncer = Debouncer(delay: .seconds(5), clock: clock)
        let ran = Box(false)

        await debouncer.run { await MainActor.run { ran.value = true } }
        #expect(!ran.value)

        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        await clock.advance(by: .seconds(5))
        // Allow the debouncer's internal task to resume and run the action.
        var iterations = 0
        while !ran.value, iterations < 1000 {
            await Task.yield()
            iterations += 1
        }

        #expect(ran.value)
    }
}
