import Foundation
import Synchronization

/// Races an operation that may ignore cancellation against a clock delay, and returns when the
/// delay expires whether or not the operation stops.
///
///     let token = try await withAbandoningTimeout(.seconds(20)) {
///         try await sdk.fetchToken()  // bridged from a completion handler; ignores cancellation
///     }
///
/// ``withTimeout(_:clock:operation:)`` waits for the cancelled operation to finish its cleanup,
/// so an operation that never checks for cancellation (a callback-based API wrapped in a
/// continuation, for example) keeps it suspended for as long as that operation hangs. This
/// function instead *abandons* the operation: it runs in an unstructured task, is cancelled when
/// the delay expires, and whatever it eventually returns or throws is discarded.
///
/// Because the abandoned work may still finish later, use this only when a late completion is
/// harmless or is handled elsewhere (for example, state the operation changes is observed through
/// its own stream). The operation does not inherit the caller's task-local values or actor.
///
/// - Parameters:
///   - duration: The delay before timing out. Zero or negative durations throw ``TimeoutError``
///     without starting the operation.
///   - clock: The clock used for the timeout delay. Defaults to ``LiveClock``.
///   - operation: The asynchronous, throwing operation to run.
/// - Returns: The operation's value if it finishes first.
/// - Throws: ``TimeoutError`` if the delay finishes first, the operation's error if it fails
///   first, or `CancellationError` when the calling task is cancelled. In every case the call
///   returns without waiting for the operation.
public func withAbandoningTimeout<Value: Sendable>(
    _ duration: Duration,
    clock: some DelayClock = LiveClock(),
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try Task.checkCancellation()
    guard duration > .zero else {
        throw TimeoutError()
    }

    let race: AbandoningRace<Value> = .init()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            race.install(continuation)
            race.track(
                Task {
                    do {
                        race.finish(.success(try await operation()))
                    } catch {
                        race.finish(.failure(error))
                    }
                }
            )
            race.track(
                Task {
                    do {
                        try await clock.sleep(for: duration)
                    } catch {
                        return
                    }
                    race.finish(.failure(TimeoutError()))
                }
            )
        }
    } onCancel: {
        race.finish(.failure(CancellationError()))
    }
}

/// The first of the operation, the timer and caller cancellation to finish resumes the caller and
/// cancels the other tasks. Every path resumes the continuation at most once.
private final class AbandoningRace<Value: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<Value, any Error>?
        var outcome: Result<Value, any Error>?
        var tasks: [Task<Void, Never>] = []
    }

    private let state: Mutex<State> = .init(State())

    /// Hands over the caller's continuation, resuming it at once if the race already finished
    /// (caller cancellation can arrive before the continuation exists).
    func install(_ continuation: CheckedContinuation<Value, any Error>) {
        let finished: Result<Value, any Error>? = state.withLock { state in
            guard let outcome = state.outcome else {
                state.continuation = continuation
                return nil
            }
            return outcome
        }
        if let finished {
            continuation.resume(with: finished)
        }
    }

    /// Registers a task to cancel when the race finishes, cancelling it now if it already has.
    func track(_ task: Task<Void, Never>) {
        let alreadyFinished: Bool = state.withLock { state in
            guard state.outcome == nil else { return true }
            state.tasks.append(task)
            return false
        }
        if alreadyFinished {
            task.cancel()
        }
    }

    /// Records the first outcome, cancels the losing tasks and resumes the caller with it. Later
    /// outcomes are ignored.
    func finish(_ outcome: Result<Value, any Error>) {
        let winner: (CheckedContinuation<Value, any Error>?, [Task<Void, Never>])? = state.withLock
        {
            state in
            guard state.outcome == nil else { return nil }
            state.outcome = outcome
            defer {
                state.continuation = nil
                state.tasks = []
            }
            return (state.continuation, state.tasks)
        }
        guard let (continuation, tasks) = winner else { return }
        // Losers are cancelled before the caller resumes, so an abandoned operation is already
        // cancelled by the time the caller observes the outcome.
        for task in tasks {
            task.cancel()
        }
        continuation?.resume(with: outcome)
    }
}
