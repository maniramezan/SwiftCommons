import Foundation

/// Coalesces rapid, repeated calls into a single action after a quiet period.
///
/// Useful for search-as-you-type fields or other UI-driven triggers where
/// only the most recent call within a time window should take effect:
///
///     let debouncer = Debouncer(delay: .milliseconds(300))
///
///     func searchFieldDidChange(_ query: String) {
///         debouncer.run {
///             await performSearch(query)
///         }
///     }
///
/// Each call to ``run(action:)`` cancels any pending action scheduled by a
/// previous call, then schedules the new action to run after `delay`. If the
/// debouncer is deallocated or a new call arrives first, a pending action
/// never runs.
public actor Debouncer {
    private let delay: Duration
    private let clock: any SwiftCommonsClock
    private var task: Task<Void, Never>?

    /// Creates a debouncer with the given quiet-period delay.
    /// - Parameters:
    ///   - delay: How long to wait after the most recent call before running
    ///     the action.
    ///   - clock: The clock used to wait out the quiet period. Defaults to
    ///     ``ContinuousSwiftCommonsClock``. Tests can inject a fake clock (see
    ///     `ManualSwiftCommonsClock` in `SwiftCommonsTestSupport`) to avoid
    ///     real delays.
    public init(delay: Duration, clock: any SwiftCommonsClock = ContinuousSwiftCommonsClock()) {
        self.delay = delay
        self.clock = clock
    }

    /// Cancels any pending action and schedules a new one after `delay`.
    /// - Parameter action: The work to perform once the quiet period elapses.
    public func run(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        let delay = delay
        let clock = clock
        task = Task {
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancels any pending action without running it.
    public func cancel() {
        task?.cancel()
        task = nil
    }
}
