import Foundation

/// An operation exceeded the duration supplied to ``withTimeout(_:clock:operation:)``.
public struct TimeoutError: Error, Equatable, Sendable, LoadingErrorClassifiable {
    /// Creates a timeout error.
    public init() {}

    /// Classifies the failure for user-facing loading state.
    public var loadingErrorKind: LoadingErrorKind { .timedOut }
}

/// Races an asynchronous operation against a clock delay.
///
///     let items = try await withTimeout(.seconds(10)) {
///         try await fetchItems()
///     }
///
/// Cancels the losing child task and waits for its cleanup before returning.
/// Cancellation is cooperative: an operation that ignores cancellation can keep
/// this function suspended beyond the requested duration. Simultaneous completion
/// and expiration may resolve in either order.
///
/// - Parameters:
///   - duration: The delay before timing out. Zero or negative durations throw
///     ``TimeoutError`` without starting the operation.
///   - clock: The clock used for the timeout delay. Defaults to ``LiveClock``.
///   - operation: The asynchronous, throwing operation to run in a child task.
/// - Returns: The operation's value if it finishes first.
/// - Throws: ``TimeoutError`` if the delay finishes first, the operation's error,
///   or an error from the clock. Parent cancellation throws `CancellationError`.
public func withTimeout<Value: Sendable>(
    _ duration: Duration,
    clock: some DelayClock = LiveClock(),
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try Task.checkCancellation()
    guard duration > .zero else {
        throw TimeoutError()
    }

    do {
        let value = try await withThrowingTaskGroup(of: Value.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                try Task.checkCancellation()
                return try await operation()
            }
            group.addTask {
                try await clock.sleep(for: duration)
                try Task.checkCancellation()
                throw TimeoutError()
            }
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            return result
        }
        try Task.checkCancellation()
        return value
    } catch {
        try Task.checkCancellation()
        throw error
    }
}
