/// A ``LoadingState`` that remembers the last value it loaded, so a screen can keep showing
/// it while it reloads or after a reload fails.
///
/// ``LoadingState/loading`` carries no value, so a plain `LoadingState` can't tell a first load
/// from a refresh. Hold this in a view model instead and bracket each load:
///
///     var items = RefreshableLoadingState<[Item]>()
///
///     items.beginLoading()
///     items.finish(with: await .load { try await api.fetchItems() })
///
///     // In the view
///     if let shown = items.displayValue { ItemList(shown).opacity(items.isRefreshing ? 0.5 : 1) }
///     else if items.isInitialLoading { ProgressView() }
///
/// The two calls are separate, synchronous mutations rather than one `async` mutating method, so
/// nothing holds exclusive access to the property across the `await`.
public struct RefreshableLoadingState<Value: Equatable & Sendable>: Equatable, Sendable {

    // MARK: Lifecycle

    /// Creates a state, remembering `state`'s value if it is already loaded.
    /// - Parameter state: The initial state. Defaults to ``LoadingState/idle``.
    public init(state: LoadingState<Value> = .idle) {
        self.state = state
        lastValue = state.value
    }

    // MARK: Public

    /// The current loading state.
    public private(set) var state: LoadingState<Value>

    /// The most recently loaded value, kept through ``LoadingState/loading``,
    /// ``LoadingState/failed(_:)`` and ``LoadingState/idle``.
    public private(set) var lastValue: Value?

    /// The value to show: the freshly loaded one, otherwise the last one loaded.
    public var displayValue: Value? { state.value ?? lastValue }

    /// `true` while reloading with an earlier value still available to show.
    public var isRefreshing: Bool { state.isLoading && lastValue != nil }

    /// `true` while loading with nothing yet to show.
    public var isInitialLoading: Bool { state.isLoading && lastValue == nil }

    /// The failure, or `nil` in any other state.
    public var error: LoadingError? { state.error }

    /// Moves to ``LoadingState/loading`` without discarding ``lastValue``.
    public mutating func beginLoading() {
        state = .loading
    }

    /// Records the outcome of a load.
    ///
    /// A loaded result replaces ``lastValue``; any other result leaves it in place.
    /// - Parameter result: The state returned by ``LoadingState/load(_:)``.
    public mutating func finish(with result: LoadingState<Value>) {
        if let loaded = result.value {
            lastValue = loaded
        }
        state = result
    }
}
