import Foundation
import SwiftCommons

/// A fake, manually-advanced clock for testing code built on
/// ``SwiftCommons/SwiftCommonsClock``, such as `withRetry` and `Debouncer`.
///
/// Calls to `sleep(for:)` suspend until the fake clock is advanced past their
/// requested duration, instead of waiting on real time:
///
///     let clock = ManualSwiftCommonsClock()
///     let debouncer = Debouncer(delay: .seconds(1), clock: clock)
///
///     await debouncer.run { /* ... */ }
///     await clock.advance(by: .seconds(1)) // resumes the pending action
///
/// This makes tests for debounced or retried behavior deterministic and
/// instantaneous instead of depending on real, wall-clock delays.
public actor ManualSwiftCommonsClock: SwiftCommonsClock {
    private struct Waiter {
        let wakeAt: Duration
        let continuation: CheckedContinuation<Void, Never>
    }

    private var elapsed: Duration = .zero
    private var waiters: [Waiter] = []

    /// Creates a fake clock starting at time zero.
    public init() {}

    /// Suspends until the clock has been advanced by at least `duration`
    /// beyond its current elapsed time.
    public func sleep(for duration: Duration) async throws {
        guard duration > .zero else { return }
        let wakeAt = elapsed + duration
        await withCheckedContinuation { continuation in
            waiters.append(Waiter(wakeAt: wakeAt, continuation: continuation))
        }
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
