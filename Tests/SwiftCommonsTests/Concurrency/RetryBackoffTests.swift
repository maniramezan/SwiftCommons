import Foundation
import SwiftCommonsTestSupport
import Testing

@testable import SwiftCommons

@Suite("RetryBackoff")
struct RetryBackoffTests {
    @Test
    func constantReturnsSameDelayForEveryRetry() {
        let backoff = RetryBackoff.constant(.milliseconds(250))
        #expect(
            (1...4).map(backoff.delay(forRetry:)) == Array(repeating: .milliseconds(250), count: 4))
    }

    @Test
    func exponentialDoublesByDefault() {
        let backoff = RetryBackoff.exponential(baseDelay: .seconds(1))
        #expect(
            (1...4).map(backoff.delay(forRetry:)) == [
                .seconds(1), .seconds(2), .seconds(4), .seconds(8),
            ])
    }

    @Test
    func exponentialUsesCustomMultiplier() {
        let backoff = RetryBackoff.exponential(baseDelay: .milliseconds(100), multiplier: 3)
        #expect(
            (1...3).map(backoff.delay(forRetry:)) == [
                .milliseconds(100), .milliseconds(300), .milliseconds(900),
            ])
    }

    @Test
    func exponentialIsCappedAtMaxDelay() {
        let backoff = RetryBackoff.exponential(baseDelay: .seconds(1), maxDelay: .seconds(5))
        #expect(
            (1...5).map(backoff.delay(forRetry:)) == [
                .seconds(1), .seconds(2), .seconds(4), .seconds(5), .seconds(5),
            ])
    }

    @Test(arguments: [
        (jitterSample: 0.0, expected: Duration.seconds(1)),
        (jitterSample: 0.5, expected: Duration.seconds(2)),
        (jitterSample: 1.0, expected: Duration.seconds(3)),
        (jitterSample: -4.0, expected: Duration.seconds(1)),
        (jitterSample: 7.0, expected: Duration.seconds(3)),
    ])
    func jitterScalesDelayWithinRange(jitterSample: Double, expected: Duration) {
        let backoff = RetryBackoff.exponential(
            baseDelay: .seconds(2), jitter: 0.5...1.5, jitterSource: { jitterSample })
        #expect(backoff.delay(forRetry: 1) == expected)
    }

    @Test
    func jitterAppliesAfterTheCap() {
        let backoff = RetryBackoff.exponential(
            baseDelay: .seconds(4), maxDelay: .seconds(10), jitter: 0.5...1.5,
            jitterSource: { 1 })
        // 4 * 2^3 = 32s, capped to 10s, then scaled by 1.5.
        #expect(backoff.delay(forRetry: 4) == .seconds(15))
    }

    @Test
    func extremeRetryCountsDoNotOverflow() {
        let uncapped = RetryBackoff.exponential(baseDelay: .seconds(1))
        #expect(uncapped.delay(forRetry: 10_000) == .seconds(Int64.max))

        let capped = RetryBackoff.exponential(baseDelay: .seconds(1), maxDelay: .seconds(60))
        #expect(capped.delay(forRetry: 10_000) == .seconds(60))

        let zeroBase = RetryBackoff.exponential(baseDelay: .zero)
        #expect(zeroBase.delay(forRetry: 10_000) == .zero)
    }
}

@Suite("withRetry backoff")
struct WithRetryBackoffTests {
    private struct TransientError: Error {}
    private struct PermanentError: Error {}

    @Test
    func waitsForEachBackoffDelayBetweenAttempts() async throws {
        let clock = RecordingClock()
        let callCount = Counter()

        let result = try await withRetry(
            attempts: 4,
            backoff: .exponential(baseDelay: .milliseconds(100)),
            clock: clock
        ) {
            let count = await callCount.increment()
            if count < 4 {
                throw TransientError()
            }
            return count
        }

        #expect(result == 4)
        #expect(await clock.sleeps == [.milliseconds(100), .milliseconds(200), .milliseconds(400)])
    }

    @Test
    func doesNotRetryAfterTheFinalAttempt() async {
        let clock = RecordingClock()
        let callCount = Counter()

        await #expect(throws: TransientError.self) {
            try await withRetry(attempts: 2, backoff: .constant(.seconds(1)), clock: clock) {
                await callCount.increment()
                throw TransientError()
            }
        }

        #expect(await callCount.value == 2)
        #expect(await clock.sleeps == [.seconds(1)])
    }

    @Test
    func stopsImmediatelyWhenShouldRetryRejectsTheError() async {
        let clock = RecordingClock()
        let callCount = Counter()

        await #expect(throws: PermanentError.self) {
            try await withRetry(
                attempts: 5,
                backoff: .constant(.seconds(1)),
                clock: clock,
                shouldRetry: { !($0 is PermanentError) },
                operation: {
                    let count = await callCount.increment()
                    if count == 1 {
                        throw TransientError()
                    }
                    throw PermanentError()
                }
            )
        }

        #expect(await callCount.value == 2)
        #expect(await clock.sleeps == [.seconds(1)])
    }

    @Test
    func retryResumesOnlyOnceTheManualClockReachesTheDelay() async throws {
        let clock = ManualClock()
        let callCount = Counter()

        let task = Task {
            try await withRetry(
                attempts: 2,
                backoff: .exponential(
                    baseDelay: .seconds(2), jitter: 0.5...1.5, jitterSource: { 0 }),
                clock: clock
            ) {
                let count = await callCount.increment()
                if count == 1 {
                    throw TransientError()
                }
                return count
            }
        }

        while await clock.waiterCount == 0 {
            await Task.yield()
        }
        // The jittered delay is 2s * 0.5 = 1s.
        await clock.advance(by: .milliseconds(999))
        #expect(await clock.waiterCount == 1)
        #expect(await callCount.value == 1)

        await clock.advance(by: .milliseconds(1))
        #expect(try await task.value == 2)
    }

    @Test
    func fixedDelayOverloadStillSleepsBetweenAttempts() async throws {
        let clock = RecordingClock()
        let callCount = Counter()

        let result = try await withRetry(attempts: 3, delay: .milliseconds(50), clock: clock) {
            let count = await callCount.increment()
            if count < 3 {
                throw TransientError()
            }
            return count
        }

        #expect(result == 3)
        #expect(await clock.sleeps == [.milliseconds(50), .milliseconds(50)])
    }

    /// A clock that records each requested sleep and returns immediately.
    private actor RecordingClock: DelayClock {
        private(set) var sleeps: [Duration] = []

        func sleep(for duration: Duration) async throws {
            sleeps.append(duration)
        }
    }

    private actor Counter {
        private(set) var value = 0

        @discardableResult
        func increment() -> Int {
            value += 1
            return value
        }
    }
}
