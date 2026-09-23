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
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates an unlocked lock.
    public init() {}

    /// Acquires the lock, suspending until it becomes available.
    public func lock() async {
        if !locked {
            locked = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Runs `body` while holding the lock, releasing it afterwards even if `body` throws.
    ///
    /// `body` runs on the caller's actor, so it may capture non-`Sendable` state.
    /// - Parameter body: The critical section.
    /// - Returns: Whatever `body` returns.
    // swift-format-ignore: swift-format 6.2 (CI) and 6.4 disagree on spacing around
    // `nonisolated(nonsending)` in a function type.
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
        if waiters.isEmpty {
            locked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
