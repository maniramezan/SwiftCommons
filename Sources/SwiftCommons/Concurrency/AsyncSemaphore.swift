import Foundation

/// A counting async semaphore for limiting concurrent access to a resource.
///
/// Use it to cap the number of concurrent tasks performing some operation
/// (e.g. limiting parallel network requests):
///
///     let semaphore = AsyncSemaphore(value: 3)
///
///     func fetch(_ url: URL) async throws -> Data {
///         try await semaphore.withPermit {
///             try await URLSession.shared.data(from: url).0
///         }
///     }
///
/// Unlike `AsyncLock`, which allows only one holder at a time, `AsyncSemaphore`
/// allows up to `value` concurrent holders. Waiters are resumed in the order
/// they arrived (first-in, first-out).
public actor AsyncSemaphore {
    private var count: Int
    private var waiters = AsyncWaiterQueue()

    /// The number of suspended waiters. Tests only.
    var waiterCount: Int { waiters.count }

    /// Creates a semaphore that allows up to `value` concurrent holders.
    /// - Parameter value: The number of concurrent permits available. Must be
    ///   at least `0`.
    public init(value: Int) {
        precondition(value >= 0, "value must be at least 0")
        count = value
    }

    /// Acquires a permit, suspending until one becomes available.
    ///
    /// Cancellation doesn't interrupt the wait: a cancelled task still queues and takes a
    /// permit in turn. Use ``waitCancellable()`` to leave the queue on cancellation.
    public func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { waiters.enqueue($0) }
    }

    /// Acquires a permit, suspending until one becomes available, and stops waiting if the
    /// task is cancelled.
    ///
    /// A cancelled waiter leaves the queue without taking a permit, so it must not call
    /// ``signal()``. If a permit is handed over just as the task is cancelled, the call
    /// returns normally and the caller owns the permit.
    /// - Throws: `CancellationError` if the task is cancelled before it acquires a permit.
    public func waitCancellable() async throws {
        try Task.checkCancellation()
        if count > 0 {
            count -= 1
            return
        }
        let id = waiters.makeID()
        try await withTaskCancellationHandler {
            try await suspendCancellably(id: id)
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    /// Releases a permit, resuming the next waiter if any.
    public func signal() {
        if !waiters.resumeNext() {
            count += 1
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

    /// Acquires a permit, runs `operation`, then releases the permit —
    /// even if `operation` throws.
    ///
    /// `operation` runs on the caller's actor, so it may capture non-`Sendable` state, like
    /// ``AsyncLock/withLock(_:)``.
    /// - Parameter operation: The work to perform while holding a permit.
    /// - Returns: The value returned by `operation`.
    // swift-format 6.2 (CI) and 6.4 disagree on spacing around `nonisolated(nonsending)` in a
    // function type, so this declaration is excluded from formatting.
    // swift-format-ignore
    nonisolated(nonsending) public func withPermit<Value>(
        _ operation: nonisolated(nonsending) () async throws -> Value
    ) async rethrows -> Value {
        await wait()
        do {
            let result = try await operation()
            await signal()
            return result
        } catch {
            await signal()
            throw error
        }
    }

    /// Like ``withPermit(_:)``, but stops waiting for a permit if the task is cancelled.
    /// - Parameter operation: The work to perform while holding a permit.
    /// - Returns: The value returned by `operation`.
    /// - Throws: `CancellationError` if the task is cancelled before it acquires a permit, or
    ///   whatever `operation` throws.
    // swift-format 6.2 (CI) and 6.4 disagree on spacing around `nonisolated(nonsending)` in a
    // function type, so this declaration is excluded from formatting.
    // swift-format-ignore
    nonisolated(nonsending) public func withPermitCancellable<Value>(
        _ operation: nonisolated(nonsending) () async throws -> Value
    ) async throws -> Value {
        try await waitCancellable()
        do {
            let result = try await operation()
            await signal()
            return result
        } catch {
            await signal()
            throw error
        }
    }
}
