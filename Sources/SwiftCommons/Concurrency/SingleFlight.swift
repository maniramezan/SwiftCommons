import Foundation

/// Coalesces concurrent async calls for the same key into one in-flight operation.
///
/// The first caller for a key starts `operation`. Every caller that arrives for that key while
/// it is still running awaits the same result instead of starting a duplicate, so a burst of
/// identical requests (a token refresh, a profile fetch) does the work once:
///
///     let profiles = SingleFlight<User.ID, Profile>()
///
///     async let first = profiles.value(for: id) { try await api.profile(id) }
///     async let second = profiles.value(for: id) { try await api.profile(id) }
///     // `api.profile(id)` runs once; both calls get its result (or its error).
///     let (a, b) = try await (first, second)
///
/// Results aren't cached: once a flight finishes, the next call for the key starts a new one.
/// Different keys run concurrently. For a single shared operation with no natural key, use a
/// constant key.
///
/// ``cancel(_:)`` and ``cancelAll()`` cancel the operation's task and detach it, so the next
/// call starts a fresh flight. Callers already waiting on a cancelled flight get
/// `CancellationError`, even if the operation ignores cancellation and returns a value. A
/// result from an invalidated flight is never treated as current.
///
/// Cancelling one *caller* doesn't cancel work shared with other callers. The cancelled caller
/// gets `CancellationError` once the shared work finishes.
public actor SingleFlight<Key: Hashable & Sendable, Value: Sendable> {
    private struct Flight {
        let id: UInt64
        let task: Task<Value, any Error>
        var callerCount: Int
    }

    private var flights: [Key: Flight] = [:]
    private var nextFlightID: UInt64 = 0

    /// Creates an instance with no calls in flight.
    public init() {}

    /// Returns the result of `operation`, sharing an in-flight call for `key` if one is running.
    ///
    /// - Parameters:
    ///   - key: Identifies calls that may share one operation.
    ///   - operation: The work to run when no call for `key` is in flight. When a call is
    ///     already in flight, this closure is ignored and the running operation's result is
    ///     returned instead.
    /// - Returns: The value produced by the shared operation.
    /// - Throws: The operation's error, or `CancellationError` if the caller is cancelled or the
    ///   flight is cancelled with ``cancel(_:)`` or ``cancelAll()`` before it finishes.
    public func value(
        for key: Key,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        let task: Task<Value, any Error>
        if var flight = flights[key] {
            flight.callerCount += 1
            flights[key] = flight
            task = flight.task
        } else {
            let id = nextFlightID
            nextFlightID += 1
            // The task can't reach `run` until this method suspends, so the flight is always
            // registered before it can finish.
            task = Task { try await self.run(operation, key: key, id: id) }
            flights[key] = Flight(id: id, task: task, callerCount: 1)
        }
        let value = try await task.value
        try Task.checkCancellation()
        return value
    }

    /// Cancels the in-flight call for `key`, if any.
    ///
    /// The operation's task is cancelled, and callers waiting on it get `CancellationError`. The
    /// next call for `key` starts a new flight.
    ///
    /// - Parameter key: The key whose call to cancel.
    public func cancel(_ key: Key) {
        flights.removeValue(forKey: key)?.task.cancel()
    }

    /// Cancels every in-flight call. See ``cancel(_:)``.
    public func cancelAll() {
        for flight in flights.values {
            flight.task.cancel()
        }
        flights.removeAll()
    }

    /// The number of callers sharing the current flight for `key`, or `0` if none is in flight.
    func callerCount(for key: Key) -> Int {
        flights[key]?.callerCount ?? 0
    }

    private func run(
        _ operation: @Sendable () async throws -> Value, key: Key, id: UInt64
    ) async throws -> Value {
        do {
            let value = try await operation()
            guard flights[key]?.id == id else {
                throw CancellationError()
            }
            flights[key] = nil
            return value
        } catch {
            if flights[key]?.id == id {
                flights[key] = nil
            }
            throw error
        }
    }
}
