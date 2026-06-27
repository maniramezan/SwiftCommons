import Foundation

/// A minimal FIFO async mutual-exclusion lock.
///
/// Use it to serialize overlapping asynchronous work so it can't run
/// concurrently across `await` suspension points — something `@MainActor` or a
/// plain actor cannot guarantee, since they only serialize synchronous regions,
/// not work spanning awaits.
///
///     let lock = AsyncLock()
///     await lock.lock()
///     defer { lock.unlock() }
///     // ... critical section that awaits ...
///
/// Waiters are resumed in the order they arrived (first-in, first-out).
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

    /// Releases the lock, resuming the next waiter if any.
    public func unlock() {
        if waiters.isEmpty {
            locked = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
