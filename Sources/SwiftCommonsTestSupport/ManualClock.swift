import Foundation
import SwiftCommons

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
///     await clock.advance(by: .seconds(1)) // resumes the pending action
///
/// This makes tests for debounced or retried behavior deterministic and
/// instantaneous instead of depending on real, wall-clock delays.
public actor ManualClock: DelayClock {
    private struct Waiter {
        let id: UUID
        let wakeAt: Duration
        let continuation: CheckedContinuation<Void, any Error>
    }

    /// Total positive-duration sleeps registered, including sleepers later cancelled.
    public private(set) var sleepCount = 0

    private var elapsed: Duration = .zero
    private var waiters: [Waiter] = []

    /// Creates a fake clock starting at time zero.
    public init() {}

    /// Suspends until the clock has been advanced by at least `duration`
    /// beyond its current elapsed time.
    public func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        guard duration > .zero else { return }
        let id = UUID()
        let wakeAt = elapsed + duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    sleepCount += 1
                    waiters.append(Waiter(id: id, wakeAt: wakeAt, continuation: continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
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
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while sleepCount < count {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { return false }
            try await Task.sleep(for: .milliseconds(1))
        }
        try Task.checkCancellation()
        return true
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    /// Advances the clock by `duration`, resuming any waiters whose requested
    /// duration has now elapsed.
    /// - Parameter duration: How far to advance the clock. Must be at least
    ///   `.zero`.
    public func advance(by duration: Duration) {
        precondition(duration >= .zero, "duration must be at least .zero")
        elapsed += duration

        let ready = waiters.filter { $0.wakeAt <= elapsed }
        waiters.removeAll { $0.wakeAt <= elapsed }
        for waiter in ready.sorted(by: { $0.wakeAt < $1.wakeAt }) {
            waiter.continuation.resume()
        }
    }

    /// The number of `sleep(for:)` calls currently suspended, waiting for the
    /// clock to advance far enough to resume them.
    ///
    /// Because code under test typically starts running on a separate `Task`,
    /// calling ``advance(by:)`` immediately after starting that work is
    /// racy — the sleep may not have been registered yet, so the advance
    /// would have no effect. Poll this property to deterministically wait
    /// until the expected number of sleeps have actually started:
    ///
    ///     let task = Task { try await withRetry(..., clock: clock) { ... } }
    ///     while await clock.waiterCount == 0 { await Task.yield() }
    ///     await clock.advance(by: someDelay)
    public var waiterCount: Int {
        waiters.count
    }
}
