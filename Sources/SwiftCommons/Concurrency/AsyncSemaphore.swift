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
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates a semaphore that allows up to `value` concurrent holders.
    /// - Parameter value: The number of concurrent permits available. Must be
    ///   at least `0`.
    public init(value: Int) {
        precondition(value >= 0, "value must be at least 0")
        count = value
    }

    /// Acquires a permit, suspending until one becomes available.
    public func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// Releases a permit, resuming the next waiter if any.
    public func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            waiters.removeFirst().resume()
        }
    }

    /// Acquires a permit, runs `operation`, then releases the permit —
    /// even if `operation` throws.
    /// - Parameter operation: The work to perform while holding a permit.
    /// - Returns: The value returned by `operation`.
    public func withPermit<Value: Sendable>(
        _ operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        await wait()
        do {
            let result = try await operation()
            signal()
            return result
        } catch {
            signal()
            throw error
        }
    }
}
