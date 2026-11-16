import Foundation

/// Limits how often an action runs: at most once per `interval`.
///
/// Where ``Debouncer`` waits for calls to stop, a throttler runs the first call right away and
/// then ignores or coalesces the calls that arrive during the next `interval`. Use it for
/// high-frequency triggers that should still make steady progress, such as scroll or drag
/// updates, or saving a draft while the user keeps typing:
///
///     let throttler = Throttler(interval: .seconds(1))
///
///     func textDidChange(_ text: String) async {
///         await throttler.run {
///             await saveDraft(text)
///         }
///     }
///
/// The first call in an idle throttler runs immediately, and ``run(action:)`` returns once it has
/// finished. Calls that arrive while the interval is open are coalesced: only the most recent one
/// is kept and runs when the interval ends, which opens a new interval. With
/// `runsTrailingCall` set to `false` those calls are dropped instead. Once an interval ends with
/// nothing waiting, the next call runs immediately again.
///
/// ``run(action:)`` is actor-isolated, so it must be awaited. The interval is waited out with an
/// injectable ``DelayClock``, so tests can use `ManualClock` from `SwiftCommonsTestSupport`.
public actor Throttler {
    private let interval: Duration
    private let runsTrailingCall: Bool
    private let clock: any DelayClock
    private var windowTask: Task<Void, Never>?
    private var pendingAction: (@Sendable () async -> Void)?

    /// Creates a throttler.
    /// - Parameters:
    ///   - interval: The minimum time between the starts of two actions.
    ///   - runsTrailingCall: Whether the most recent call that arrives during an interval runs
    ///     when the interval ends. Defaults to `true`; `false` drops such calls.
    ///   - clock: The clock used to wait out the interval. Defaults to ``LiveClock``.
    public init(
        interval: Duration,
        runsTrailingCall: Bool = true,
        clock: any DelayClock = LiveClock()
    ) {
        self.interval = interval
        self.runsTrailingCall = runsTrailingCall
        self.clock = clock
    }

    deinit {
        windowTask?.cancel()
    }

    /// Runs `action` now if no interval is open; otherwise coalesces it.
    ///
    /// - Parameter action: The work to perform. When it runs immediately, this call returns after
    ///   it finishes; when it is coalesced, this call returns right away.
    public func run(action: @escaping @Sendable () async -> Void) async {
        guard windowTask == nil else {
            if runsTrailingCall {
                pendingAction = action
            }
            return
        }
        openWindow()
        await action()
    }

    /// Drops any waiting call and closes the open interval, so the next call runs immediately.
    public func cancel() {
        windowTask?.cancel()
        windowTask = nil
        pendingAction = nil
    }

    private func openWindow() {
        let interval = interval
        let clock = clock
        // Weak, so a dropped throttler still deinitializes (and cancels its interval).
        windowTask = Task { [weak self] in
            while true {
                do {
                    try await clock.sleep(for: interval)
                } catch {
                    return
                }
                guard await self?.endWindowOrRunTrailingCall() == true else { return }
            }
        }
    }

    /// Runs the waiting call, if any. Returns `true` to keep the interval going, or `false`
    /// after closing it because nothing was waiting (or the throttler was cancelled).
    private func endWindowOrRunTrailingCall() async -> Bool {
        guard !Task.isCancelled else { return false }
        guard let next = pendingAction else {
            windowTask = nil
            return false
        }
        pendingAction = nil
        await next()
        return true
    }
}
