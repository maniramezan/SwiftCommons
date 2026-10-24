import Foundation

/// A minimal, dependency-injectable clock abstraction for suspending a fixed
/// duration.
///
/// `withRetry(attempts:delay:clock:operation:)`, `withTimeout(_:clock:operation:)`, and `Debouncer` accept a
/// clock so tests can substitute a fake (see `ManualClock` in the
/// `SwiftCommonsTestSupport` module) instead of waiting on real time.
/// Production call sites can use the default ``LiveClock``.
public protocol DelayClock: Sendable {
    /// Suspends the calling task for approximately `duration`.
    ///
    /// Implementations should throw `CancellationError` when cancelled so callers
    /// can promptly clean up pending delays.
    /// - Parameter duration: How long to suspend for.
    func sleep(for duration: Duration) async throws
}

/// The default, real-time clock, backed by `Task.sleep(for:)`.
public struct LiveClock: DelayClock {
    /// Creates the default real-time clock.
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
