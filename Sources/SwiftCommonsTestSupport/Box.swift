import Foundation

/// A mutable capture reference for recording values from within `@Sendable`
/// async closures during tests.
///
/// Swift's strict concurrency checking prevents mutating a plain captured
/// `var` from within a `@Sendable` closure. `Box` sidesteps that by being
/// `@MainActor`-isolated, so tests that run on the main actor (the default
/// for Swift Testing) can freely read and write it:
///
///     let requests = Box<[Request]>([])
///     let adapter = SyncFixtures.adapter(call: { request in
///         requests.value.append(request)
///         return .init(...)
///     })
@MainActor
public final class Box<Value> {
    /// The current captured value.
    public var value: Value

    /// Creates a box wrapping an initial value.
    public init(_ value: Value) {
        self.value = value
    }
}

/// Builds a call closure — suitable for `SyncResourceAdapter`'s `call:`
/// parameter — that records every request it receives into `box` and always
/// returns `response`.
///
///     let requests = Box<[Request]>([])
///     let adapter = SyncResourceAdapter(
///         // ...
///         call: recordingCall(returning: response, into: requests)
///     )
///     // ... run the sync pass ...
///     #expect(requests.value.count == 1)
///
/// - Parameters:
///   - response: The response every recorded call returns.
///   - box: The box requests are appended to, in call order.
/// - Returns: A closure that records each request into `box` and returns
///   `response`.
public func recordingCall<Request: Sendable, Response: Sendable>(
    returning response: Response,
    into box: Box<[Request]>
) -> @Sendable (Request) async throws -> Response {
    { request in
        await MainActor.run { box.value.append(request) }
        return response
    }
}
