import Foundation
import SwiftCommons
import TestCommons

/// A fake, manually-advanced clock for testing code built on
/// ``SwiftCommons/DelayClock``, such as `withRetry` and `Debouncer`.
///
/// Calls to `sleep(for:)` suspend until the fake clock is advanced past their
/// requested duration, instead of waiting on real time:
///
///     let clock = ManualClock()
///     let debouncer = Debouncer(delay: .seconds(1), clock: clock)
///
///     await debouncer.run { /* ... */ }
///     try #require(await clock.waitForSleepCount(1))
///     await clock.advance(by: .seconds(1)) // resumes the pending action
///
/// This makes tests for debounced or retried behavior deterministic and
/// instantaneous instead of depending on real, wall-clock delays.
public actor ManualClock: DelayClock {
    private let clock = TestCommons.ManualClock()

    /// Total positive-duration sleeps registered, including sleepers later cancelled.
    public private(set) var sleepCount = 0

    /// Creates a fake clock starting at time zero.
    public init() {}

    /// Suspends until the clock has been advanced by at least `duration`
    /// beyond its current elapsed time.
    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        guard duration > .zero else { return }
        // Capture the deadline before counting the sleep. If a caller advances after
        // observing sleepCount, a late registration still sees the elapsed deadline.
        let deadline = clock.now.advanced(by: duration)
        sleepCount += 1
        try await clock.sleep(until: deadline)
        try Task.checkCancellation()
    }

    /// Waits for a cumulative number of sleeps to register, without advancing fake time.
    /// - Parameters:
    ///   - count: The nonnegative minimum registered sleep count.
    ///   - timeout: The nonnegative monotonic observation budget.
    /// - Returns: Whether enough sleeps registered before the deadline.
    /// - Throws: Cancellation of the observing task.
    public func waitForSleepCount(_ count: Int, timeout: Duration = .seconds(2)) async throws
        -> Bool
    {
        precondition(count >= 0 && timeout >= .zero)
        do {
            _ = try await waitUntil(
                timeout: timeout, pollInterval: .milliseconds(1),
                operation: { await self.sleepCount }, matching: { $0 >= count })
            return true
        } catch is ObservationTimeout<Int> {
            return false
        }
    }

    /// Advances the clock by `duration`, resuming any waiters whose requested
    /// duration has now elapsed.
    /// - Parameter duration: How far to advance the clock. Must be at least
    ///   `.zero`.
    public func advance(by duration: Duration) {
        precondition(duration >= .zero, "duration must be at least .zero")
        clock.advance(by: duration)
    }

    /// The number of `sleep(for:)` calls currently suspended, waiting for the
    /// clock to advance far enough to resume them.
    ///
    /// Use ``waitForSleepCount(_:timeout:)`` before advancing to observe sleeps with
    /// a bounded wait, including sleeps that were later cancelled. This property
    /// reports only currently suspended sleeps and is useful for cancellation assertions.
    public var waiterCount: Int {
        clock.sleeperCount
    }
}
