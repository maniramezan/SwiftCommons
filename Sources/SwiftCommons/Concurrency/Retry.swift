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
    precondition(attempts >= 1, "attempts must be at least 1")

    var lastError: Error!
    for attempt in 0..<attempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            let isLastAttempt = attempt == attempts - 1
            if isLastAttempt {
                break
            }
            if delay > .zero {
                try await clock.sleep(for: delay)
            } else {
                try Task.checkCancellation()
            }
        }
    }
    throw lastError
}
