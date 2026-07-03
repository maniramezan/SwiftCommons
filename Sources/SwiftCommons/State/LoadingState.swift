import Foundation

/// A generic state machine for asynchronous data loading.
///
/// Model a screen or view-model's fetch lifecycle with a single value:
///
///     var state: LoadingState<[Item]> = .idle
///     state = .loading
///     state = .loaded(items)
///     // or
///     state = .failed(LoadingError(message: "No network."))
///
/// The convenience accessors (``isLoading``, ``isLoaded``, ``value``,
/// ``error``) keep call sites free of `if case` pattern matching.
public enum LoadingState<Value: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case loading
    case loaded(Value)
    case failed(LoadingError)

    // MARK: Public

    /// `true` while the value is being loaded.
    public var isLoading: Bool { if case .loading = self { true } else { false } }

    /// `true` once a value has been loaded.
    public var isLoaded: Bool { if case .loaded = self { true } else { false } }

    /// The loaded value, or `nil` in any other state.
    public var value: Value? { if case .loaded(let value) = self { value } else { nil } }

    /// The failure, or `nil` in any other state.
    public var error: LoadingError? { if case .failed(let error) = self { error } else { nil } }

    /// Runs a throwing async operation and maps its outcome to ``loaded(_:)``
    /// or ``failed(_:)``.
    ///
    ///     state = await .load { try await api.fetchItems() }
    ///
    /// Thrown errors are converted with ``LoadingError/init(from:)``, which
    /// discards internal error details in favor of a generic, user-safe
    /// message. Call sites that need error-type-specific messaging should
    /// catch the error themselves and construct a ``LoadingError`` directly.
    ///
    /// - Parameter operation: The asynchronous, throwing operation to run.
    /// - Returns: ``loaded(_:)`` with the operation's result, or
    ///   ``failed(_:)`` if it threw.
    public static func load(
        _ operation: () async throws -> Value
    ) async -> LoadingState<Value> {
        do {
            return .loaded(try await operation())
        } catch {
            return .failed(LoadingError(from: error))
        }
    }
}

/// A user-presentable failure produced while loading.
public struct LoadingError: Error, Equatable, Sendable {

    // MARK: Lifecycle

    /// Creates a failure with an explicit, user-facing message.
    ///
    /// - Parameters:
    ///   - message: A message safe to show to users.
    ///   - isRetryable: Whether the operation can be retried. Defaults to `true`.
    ///   - requiresSignIn: Whether resolving the failure requires signing in.
    ///     Defaults to `false`.
    public init(message: String, isRetryable: Bool = true, requiresSignIn: Bool = false) {
        self.message = message
        self.isRetryable = isRetryable
        self.requiresSignIn = requiresSignIn
    }

    /// Creates a failure from an arbitrary error using a generic, safe message.
    ///
    /// Internal error details (e.g. "Unauthorized access", stack traces) are
    /// never exposed to users. Callers that need error-type-specific messaging
    /// should use ``init(message:isRetryable:requiresSignIn:)`` directly.
    public init(from error: Error) {
        message = "Something went wrong. Please try again."
        isRetryable = true
        requiresSignIn = false
    }

    // MARK: Public

    /// A message safe to show to users.
    public let message: String
    /// Whether the failed operation can be retried.
    public let isRetryable: Bool
    /// When `true`, the error view should show a Sign In button alongside or
    /// instead of Retry.
    public let requiresSignIn: Bool
}
