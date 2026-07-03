import Foundation

/// The local synchronization state of a ``SyncableModel`` row.
///
/// The ``SyncEngine`` reads this to decide what to push and which rows to
/// protect from being clobbered by server changes, and writes it back when a
/// server acknowledgement or tombstone is applied.
public enum SyncState: String, Codable, Sendable, CaseIterable {
    /// In sync with the server; safe to overwrite from server changes.
    case synced
    /// Created locally and not yet accepted by the server.
    case pendingCreate
    /// Updated locally and not yet pushed to the server.
    case pendingUpdate
    /// Soft-deleted locally and not yet confirmed by the server.
    case pendingDelete
    /// Rejected or blocked by the server (for example, a quota limit).
    case blocked
}
