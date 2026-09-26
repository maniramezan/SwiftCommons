import Foundation

/// Retries an asynchronous, throwing operation with a fixed delay between attempts.
///
///     let data = try await withRetry(attempts: 3, delay: .seconds(1)) {
///         try await fetchData()
///     }
///
/// The operation is attempted up to `attempts` times. If it keeps throwing,
/// the error from the final attempt is rethrown. Cancellation is honored
/// between attempts: if the surrounding task is cancelled, the delay's
/// `CancellationError` (or the operation's own thrown error) propagates
/// immediately instead of retrying.
///
/// For exponential backoff, jitter, or retrying only some errors, use
/// ``withRetry(attempts:backoff:clock:shouldRetry:operation:)``.
///
/// - Parameters:
///   - attempts: The maximum number of attempts. Must be at least `1`.
///   - delay: The delay awaited between attempts. Not applied after the final
///     attempt. Defaults to `.zero`.
///   - clock: The clock used to wait between attempts. Defaults to
///     ``ContinuousSwiftCommonsClock``. Tests can inject a fake clock (see
///     `ManualSwiftCommonsClock` in `SwiftCommonsTestSupport`) to avoid real
///     delays.
///   - operation: The asynchronous, throwing operation to attempt.
/// - Returns: The value returned by `operation` on its first successful attempt.
/// - Throws: The error thrown by the final attempt, or `CancellationError` if
///   cancelled while waiting between attempts.
public func withRetry<Value: Sendable>(
    attempts: Int,
    delay: Duration = .zero,
    clock: some SwiftCommonsClock = ContinuousSwiftCommonsClock(),
    operation: @Sendable () async throws -> Value
) async throws -> Value {
    try await withRetry(
        attempts: attempts, backoff: .constant(delay), clock: clock, operation: operation)
}

/// Retries an asynchronous, throwing operation, waiting between attempts according to `backoff`.
///
///     let data = try await withRetry(
///         attempts: 5,
///         backoff: .exponential(baseDelay: .seconds(1), maxDelay: .seconds(30), jitter: 0.5...1.5),
///         shouldRetry: { ($0 as? URLError)?.code == .timedOut },
///         operation: { try await fetchData() }
///     )
///
/// The operation is attempted up to `attempts` times. An error that `shouldRetry` rejects is
/// rethrown immediately; otherwise the error from the final attempt is rethrown. Cancellation is
/// honored between attempts: if the surrounding task is cancelled, the delay's
/// `CancellationError` (or the operation's own thrown error) propagates immediately instead of
/// retrying.
///
/// - Parameters:
///   - attempts: The maximum number of attempts, including the first. Must be at least `1`.
///   - backoff: The delay before each retry. See ``RetryBackoff``.
///   - clock: The clock used to wait between attempts. Defaults to
///     ``ContinuousSwiftCommonsClock``. Tests can inject a fake clock (see
///     `ManualSwiftCommonsClock` in `SwiftCommonsTestSupport`) to avoid real delays.
///   - shouldRetry: Decides whether a thrown error is worth retrying. Not called for the final
///     attempt's error. Defaults to retrying every error.
///   - operation: The asynchronous, throwing operation to attempt.
/// - Returns: The value returned by `operation` on its first successful attempt.
/// - Throws: The first error `shouldRetry` rejects, the error thrown by the final attempt, or
///   `CancellationError` if cancelled while waiting between attempts.
public func withRetry<Value: Sendable>(
    attempts: Int,
    backoff: RetryBackoff,
    clock: some SwiftCommonsClock = ContinuousSwiftCommonsClock(),
    shouldRetry: @Sendable (any Error) -> Bool = { _ in true },
    operation: @Sendable () async throws -> Value
) async throws -> Value {
    precondition(attempts >= 1, "attempts must be at least 1")

    for attempt in 1...attempts {
        do {
            return try await operation()
        } catch {
            let isLastAttempt = attempt == attempts
            if isLastAttempt || !shouldRetry(error) {
                throw error
            }
            let delay = backoff.delay(forRetry: attempt)
            if delay > .zero {
                try await clock.sleep(for: delay)
            } else {
                try Task.checkCancellation()
            }
        }
    }
    fatalError("unreachable: the loop above always returns or throws before exiting")
}
