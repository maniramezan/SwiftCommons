import SwiftCommons
import Testing

/// Asserts that `state` is `.loaded` and returns its value, recording a test
/// failure at `sourceLocation` otherwise.
///
///     let state = await LoadingState.load { try await fetchItems() }
///     let items = expectLoaded(state)
///
/// - Parameters:
///   - state: The state to check.
///   - sourceLocation: Where to attribute a failure. Defaults to the call site.
/// - Returns: The wrapped value if `state` is `.loaded`, otherwise `nil`.
@discardableResult
public func expectLoaded<Value: Equatable & Sendable>(
    _ state: LoadingState<Value>,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Value? {
    guard case .loaded(let value) = state else {
        Issue.record(
            "Expected .loaded, got \(state)", sourceLocation: sourceLocation)
        return nil
    }
    return value
}

/// Asserts that `state` is `.failed` and returns its error, recording a test
/// failure at `sourceLocation` otherwise.
///
///     let state = await LoadingState<Int>.load { throw SomeError() }
///     let error = expectFailed(state)
///     #expect(error?.isRetryable == true)
///
/// - Parameters:
///   - state: The state to check.
///   - sourceLocation: Where to attribute a failure. Defaults to the call site.
/// - Returns: The `LoadingError` if `state` is `.failed`, otherwise `nil`.
@discardableResult
public func expectFailed<Value: Equatable & Sendable>(
    _ state: LoadingState<Value>,
    sourceLocation: SourceLocation = #_sourceLocation
) -> LoadingError? {
    guard case .failed(let error) = state else {
        Issue.record(
            "Expected .failed, got \(state)", sourceLocation: sourceLocation)
        return nil
    }
    return error
}
