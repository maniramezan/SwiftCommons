import Foundation
import os

/// Fans one source of values out to any number of independent `AsyncStream`s.
///
///     let broadcaster = AsyncBroadcaster<Event>()
///
///     // Each consumer gets its own stream.
///     Task { for await event in broadcaster.makeStream() { handle(event) } }
///
///     broadcaster.yield(.started)
///     broadcaster.finish()  // ends every stream
///
/// Pass `replaysLatest: true` (or seed a value with ``init(initialValue:bufferingPolicy:)``)
/// when a new consumer should immediately receive the most recent value — for example a
/// reachability monitor whose subscribers need the current status, not just the next change.
///
/// ``makeStream()`` registers the new stream synchronously, before it returns, and a stream is
/// unregistered synchronously when its consumer stops iterating (or drops the stream). There is
/// no window in which a registration can race its own removal, so cancelling a consumer
/// immediately after subscribing never leaks its continuation.
///
/// All methods are synchronous and safe to call from any thread or task. Values are delivered to
/// every stream in the order they were yielded, even when ``yield(_:)`` is called concurrently.
/// Deallocating the broadcaster finishes every stream it created.
public final class AsyncBroadcaster<Element: Sendable>: Sendable {
    private struct State: Sendable {
        var continuations: [UInt64: AsyncStream<Element>.Continuation] = [:]
        var nextID: UInt64 = 0
        var latest: Element?
        var isFinished = false
    }

    private let replaysLatest: Bool
    private let bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy
    private let state: OSAllocatedUnfairLock<State>

    /// Creates a broadcaster.
    ///
    /// - Parameters:
    ///   - replaysLatest: When `true`, each new stream immediately receives the most recently
    ///     yielded value, if any. Defaults to `false`: streams only see values yielded after
    ///     they were created.
    ///   - bufferingPolicy: The buffering policy applied to each stream, for consumers that fall
    ///     behind. Defaults to `.unbounded`; use `.bufferingNewest(1)` for "latest state"
    ///     streams where only the newest value matters.
    public init(
        replaysLatest: Bool = false,
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) {
        self.replaysLatest = replaysLatest
        self.bufferingPolicy = bufferingPolicy
        self.state = OSAllocatedUnfairLock(initialState: State())
    }

    /// Creates a broadcaster that replays the latest value, seeded with `initialValue`.
    ///
    /// Every new stream starts with `initialValue` until the first ``yield(_:)`` replaces it.
    ///
    /// - Parameters:
    ///   - initialValue: The value replayed to streams created before anything is yielded.
    ///   - bufferingPolicy: The buffering policy applied to each stream. Defaults to `.unbounded`.
    public convenience init(
        initialValue: Element,
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded
    ) {
        self.init(replaysLatest: true, bufferingPolicy: bufferingPolicy)
        state.withLock { $0.latest = initialValue }
    }

    deinit {
        finish()
    }

    /// The number of streams currently registered to receive values.
    ///
    /// A stream is removed as soon as its consumer stops iterating, the stream is dropped, or
    /// ``finish()`` is called.
    public var subscriberCount: Int {
        state.withLock { $0.continuations.count }
    }

    /// Returns a new stream that receives every value yielded from now on.
    ///
    /// If the broadcaster replays the latest value and one is available, the stream starts with
    /// it. A stream created after ``finish()`` finishes immediately without any values.
    ///
    /// - Returns: An independent stream for one consumer.
    public func makeStream() -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Element.self, bufferingPolicy: bufferingPolicy)
        let replaysLatest = replaysLatest
        let isRegistered = state.withLock { state -> Bool in
            guard !state.isFinished else { return false }
            let id = state.nextID
            state.nextID += 1
            state.continuations[id] = continuation
            // Setting the handler never invokes it here, so this can't re-enter the lock.
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
            // Replay inside the lock so a concurrent `yield` can't overtake the stale value.
            if replaysLatest, let latest = state.latest {
                continuation.yield(latest)
            }
            return true
        }
        if !isRegistered {
            continuation.finish()
        }
        return stream
    }

    /// Delivers `value` to every registered stream.
    ///
    /// Ignored after ``finish()``.
    ///
    /// - Parameter value: The value to broadcast.
    public func yield(_ value: Element) {
        let replaysLatest = replaysLatest
        state.withLock { state in
            guard !state.isFinished else { return }
            if replaysLatest {
                state.latest = value
            }
            for continuation in state.continuations.values {
                continuation.yield(value)
            }
        }
    }

    /// Finishes every registered stream and stops accepting new values.
    ///
    /// Consumers receive any values already buffered before their stream ends. Streams created
    /// afterwards finish immediately. Calling `finish()` more than once has no further effect.
    public func finish() {
        let continuations = state.withLock { state -> [AsyncStream<Element>.Continuation] in
            guard !state.isFinished else { return [] }
            state.isFinished = true
            state.latest = nil
            let continuations = Array(state.continuations.values)
            state.continuations.removeAll()
            return continuations
        }
        // Finish outside the lock: `finish()` runs each stream's `onTermination` synchronously,
        // which takes the lock again.
        for continuation in continuations {
            continuation.finish()
        }
    }

    private func removeContinuation(_ id: UInt64) {
        state.withLock { _ = $0.continuations.removeValue(forKey: id) }
    }
}
