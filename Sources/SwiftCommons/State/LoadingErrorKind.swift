/// A coarse loading failure category, suitable for choosing localized presentation.
public enum LoadingErrorKind: Hashable, Sendable {
    /// The device cannot connect to the network.
    case offline
    /// An operation exceeded its allotted time.
    case timedOut
    /// A failure without a more specific safe category.
    case other
}

/// Lets an error expose a safe loading category without a dependency on its concrete type.
///
/// Conform domain or transport errors in the module that owns them. ``LoadingError``
/// uses only this category when selecting a message and never displays the error's
/// internal description. Apps can use ``LoadingError/kind`` to choose localized copy.
public protocol LoadingErrorClassifiable {
    /// The safe category used when presenting the failure.
    var loadingErrorKind: LoadingErrorKind { get }
}
