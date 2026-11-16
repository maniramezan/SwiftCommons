import Foundation

/// A minimal FIFO async mutual-exclusion lock.
///
/// Use it to serialize overlapping asynchronous work so it can't run
/// concurrently across `await` suspension points — something `@MainActor` or a
/// plain actor cannot guarantee, since they only serialize synchronous regions,
/// not work spanning awaits.
///
///     let lock = AsyncLock()
///     let value = try await lock.withLock {
///         // ... critical section that awaits ...
///     }
///
/// Prefer ``withLock(_:)``, which releases the lock on both return and throw. Pair
/// ``lock()`` / ``unlock()`` by hand only when acquisition and release happen in
/// different scopes; `unlock()` is actor-isolated, so it can't be called from a `defer`.
///
/// Waiters are resumed in the order they arrived (first-in, first-out). The lock is not
/// reentrant: acquiring it again from inside its own critical section deadlocks.
public actor AsyncLock {
    private var locked = false
    private var waiters = AsyncWaiterQueue()

    /// The number of suspended acquirers. Tests only.
    var waiterCount: Int { waiters.count }

    /// Creates an unlocked lock.
    public init() {}

    /// Acquires the lock, suspending until it becomes available.
    ///
    /// Cancellation doesn't interrupt the wait: a cancelled task still queues and acquires the
    /// lock in turn. Use ``lockCancellable()`` to leave the queue on cancellation.
    public func lock() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { waiters.enqueue($0) }
    }

    /// Acquires the lock, suspending until it becomes available, and stops waiting if the task
    /// is cancelled.
    ///
    /// A cancelled waiter leaves the queue without ever holding the lock, so it must not call
    /// ``unlock()``. If the lock is handed over just as the task is cancelled, the call returns
    /// normally and the caller owns the lock.
    /// - Throws: `CancellationError` if the task is cancelled before it acquires the lock.
    public func lockCancellable() async throws {
        try Task.checkCancellation()
        if !locked {
            locked = true
            return
        }
        let id = waiters.makeID()
        try await withTaskCancellationHandler {
            try await suspendCancellably(id: id)
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    /// Like ``withLock(_:)``, but stops waiting for the lock if the task is cancelled.
    ///
    /// `body` runs on the caller's actor, so it may capture non-`Sendable` state.
    /// - Parameter body: The critical section.
    /// - Returns: Whatever `body` returns.
    /// - Throws: `CancellationError` if the task is cancelled before it acquires the lock, or
    ///   whatever `body` throws.
    // swift-format 6.2 (CI) and 6.4 disagree on spacing around `nonisolated(nonsending)` in a
    // function type, so this declaration is excluded from formatting.
    // swift-format-ignore
    nonisolated(nonsending) public func withLockCancellable<Result>(
        _ body: nonisolated(nonsending) () async throws -> Result
    ) async throws -> Result {
        try await lockCancellable()
        do {
            let result = try await body()
            await unlock()
            return result
        } catch {
            await unlock()
            throw error
        }
    }

    /// Runs `body` while holding the lock, releasing it afterwards even if `body` throws.
    ///
    /// `body` runs on the caller's actor, so it may capture non-`Sendable` state.
    /// - Parameter body: The critical section.
    /// - Returns: Whatever `body` returns.
    // swift-format 6.2 (CI) and 6.4 disagree on spacing around `nonisolated(nonsending)` in a
    // function type, so this declaration is excluded from formatting.
    // swift-format-ignore
    nonisolated(nonsending) public func withLock<Result>(
        _ body: nonisolated(nonsending) () async throws -> Result
    ) async rethrows -> Result {
        await lock()
        do {
            let result = try await body()
            await unlock()
            return result
        } catch {
            await unlock()
            throw error
        }
    }

    /// Releases the lock, resuming the next waiter if any.
    public func unlock() {
        if !waiters.resumeNext() {
            locked = false
        }
    }

    private func suspendCancellably(id: Int) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            } else {
                waiters.enqueue(continuation, id: id)
            }
        }
    }

    private func cancelWaiter(id: Int) {
        waiters.cancel(id: id)
    }
}
