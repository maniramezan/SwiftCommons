import Foundation

/// Coalesces rapid, repeated calls into a single action after a quiet period.
///
/// Useful for search-as-you-type fields or other UI-driven triggers where
/// only the most recent call within a time window should take effect:
///
///     let debouncer = Debouncer(delay: .milliseconds(300))
///
///     func searchFieldDidChange(_ query: String) async {
///         await debouncer.run {
///             await performSearch(query)
///         }
///     }
///
/// ``run(action:)`` is actor-isolated, so it must be awaited. From synchronous code,
/// wrap it in a `Task`, keeping in mind that separate tasks may reach the actor out of
/// order.
///
/// Each call to ``run(action:)`` cancels any pending action scheduled by a
/// previous call, then schedules the new action to run after `delay`. If the
/// debouncer is deallocated or a new call arrives first, a pending action
/// never runs. Call ``flush()`` to run the pending action immediately instead, for example
/// when a screen closes with an edit still waiting out its quiet period.
public actor Debouncer {
    private let delay: Duration
    private let clock: any DelayClock
    private var task: Task<Void, Never>?
    private var pendingAction: (@Sendable () async -> Void)?

    /// Creates a debouncer with the given quiet-period delay.
    /// - Parameters:
    ///   - delay: How long to wait after the most recent call before running
    ///     the action.
    ///   - clock: The clock used to wait out the quiet period. Defaults to
    ///     ``LiveClock``. Tests can inject a fake clock (see
    ///     `ManualClock` in `SwiftCommonsTestSupport`) to avoid
    ///     real delays.
    public init(delay: Duration, clock: any DelayClock = LiveClock()) {
        self.delay = delay
        self.clock = clock
    }

    /// Cancels any pending action and schedules a new one after `delay`.
    /// - Parameter action: The work to perform once the quiet period elapses.
    public func run(action: @escaping @Sendable () async -> Void) {
        task?.cancel()
        pendingAction = action
        let delay = delay
        let clock = clock
        // Weak, so a dropped debouncer still deinitializes (and cancels its timer).
        task = Task { [weak self] in
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            await self?.fire()
        }
    }

    private func fire() async {
        guard !Task.isCancelled, let action = pendingAction else { return }
        pendingAction = nil
        await action()
    }

    /// Runs the pending action now, without waiting out the rest of the quiet period.
    ///
    /// Does nothing when no action is pending. The action runs at most once: the scheduled run
    /// is cancelled, and a later call to ``run(action:)`` starts a fresh quiet period.
    /// - Returns: `true` if a pending action was run, `false` if there was none.
    @discardableResult
    public func flush() async -> Bool {
        guard let action = pendingAction else { return false }
        task?.cancel()
        task = nil
        pendingAction = nil
        await action()
        return true
    }

    deinit {
        task?.cancel()
    }

    /// Cancels any pending action without running it.
    public func cancel() {
        task?.cancel()
        task = nil
        pendingAction = nil
    }
}
