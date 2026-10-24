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
    /// discards internal error details in favor of a safe message based on the
    /// error's loading category. Call sites that need custom messaging should
    /// catch the error themselves and construct a ``LoadingError`` directly.
    ///
    /// Cancellation is not a failure: if the surrounding task is cancelled, or the
    /// operation throws `CancellationError` or `URLError.cancelled`, the result is
    /// ``idle`` — so a SwiftUI `.task` cancelled when its view disappears never
    /// flashes an error, and the next appearance loads again.
    ///
    /// The operation runs on the caller's actor, so it may capture non-`Sendable`
    /// state (for example a `@MainActor` view model).
    ///
    /// - Parameter operation: The asynchronous, throwing operation to run.
    /// - Returns: ``loaded(_:)`` with the operation's result, ``idle`` if the
    ///   work was cancelled, or ``failed(_:)`` if it threw.
    // swift-format 6.2 (CI) and 6.4 disagree on spacing around `nonisolated(nonsending)` in a
    // function type, so this declaration is excluded from formatting.
    // swift-format-ignore
    nonisolated(nonsending) public static func load(
        _ operation: nonisolated(nonsending) () async throws -> Value
    ) async -> LoadingState<Value> {
        do {
            return .loaded(try await operation())
        } catch  where Task.isCancelled || LoadingError.isCancellation(error) {
            return .idle
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
        self.init(
            message: message, isRetryable: isRetryable, requiresSignIn: requiresSignIn,
            kind: .other)
    }

    /// Creates a failure with an explicit message and a safe category.
    ///
    /// - Parameters:
    ///   - message: A message safe to show to users, such as app-localized copy.
    ///   - isRetryable: Whether the operation can be retried. Defaults to `true`.
    ///   - requiresSignIn: Whether resolving the failure requires signing in. Defaults to `false`.
    ///   - kind: The safe failure category to preserve for presentation.
    public init(
        message: String, isRetryable: Bool = true, requiresSignIn: Bool = false,
        kind: LoadingErrorKind
    ) {
        self.message = message
        self.isRetryable = isRetryable
        self.requiresSignIn = requiresSignIn
        self.kind = kind
    }

    /// Creates a failure from an arbitrary error using a category-specific, safe message.
    ///
    /// Internal error details (e.g. "Unauthorized access", stack traces) are
    /// never exposed to users. ``LoadingErrorClassifiable`` supplies the category
    /// when implemented; otherwise `URLError.notConnectedToInternet` and
    /// `URLError.timedOut` are recognized, and other failures use `.other`.
    /// Callers can map ``kind`` to localized copy or pass their own message to
    /// ``init(message:isRetryable:requiresSignIn:kind:)``.
    public init(from error: Error) {
        if let classified = error as? any LoadingErrorClassifiable {
            kind = classified.loadingErrorKind
        } else if let urlError = error as? URLError {
            kind =
                switch urlError.code {
                case .notConnectedToInternet: .offline
                case .timedOut: .timedOut
                default: .other
                }
        } else {
            kind = .other
        }
        message =
            switch kind {
            case .offline: "Unable to connect. Please check your internet connection and try again."
            case .timedOut: "The request timed out. Please try again."
            case .other: "Something went wrong. Please try again."
            }
        isRetryable = true
        requiresSignIn = false
    }

    // MARK: Public

    /// The safe category of the failure, which apps can map to localized presentation.
    public let kind: LoadingErrorKind

    /// Whether `error` represents cancellation rather than a failure:
    /// `CancellationError` or `URLError.cancelled`.
    public static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// A message safe to show to users.
    public let message: String
    /// Whether the failed operation can be retried.
    public let isRetryable: Bool
    /// When `true`, the error view should show a Sign In button alongside or
    /// instead of Retry.
    public let requiresSignIn: Bool
}
