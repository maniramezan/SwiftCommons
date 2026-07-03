import Foundation

/// A lifecycle event emitted by the ``SyncEngine`` during a resource pass.
///
/// Supply a handler to ``SyncEngine/init(modelContainer:limit:lock:events:logger:)``
/// to forward these to analytics, metrics, or logging. The engine never assumes
/// a particular sink, so the same event stream works across apps.
public enum SyncEvent: Sendable, Equatable {
    /// A pass started for the named resource.
    case started(resource: String)
    /// A pass completed successfully.
    /// - Parameters:
    ///   - resource: The resource that synced.
    ///   - mode: The final page mode (`"full"` or a delta mode).
    ///   - applied: Number of acknowledgements applied.
    ///   - serverChanges: Number of server changes ingested across all pages.
    ///   - durationMs: Wall-clock duration in milliseconds.
    case completed(
        resource: String,
        mode: String,
        applied: Int,
        serverChanges: Int,
        durationMs: Int
    )
    /// A pass failed with an error.
    /// - Parameters:
    ///   - resource: The resource that failed.
    ///   - errorType: The error's type name.
    ///   - message: The error's localized description.
    case failed(resource: String, errorType: String, message: String)
    /// The server blocked or rejected a pushed item.
    /// - Parameters:
    ///   - resource: The affected resource.
    ///   - status: The server status string (`blocked` or `rejected`).
    ///   - reason: A human-readable reason, when provided.
    case itemBlocked(resource: String, status: String, reason: String?)
    /// A full resync was triggered because the delta cursor was too old.
    case fullResyncStarted(resource: String)
}
