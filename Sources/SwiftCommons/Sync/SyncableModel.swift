import Foundation

/// Sync bookkeeping shared by every locally-synced model.
///
/// The ``SyncEngine`` drives all resources through one generic loop. Conforming
/// to this protocol is what lets a model plug into that loop: the engine reads
/// ``syncState`` and ``localUpdatedAt`` to decide what to push and which rows to
/// protect, and writes the bookkeeping fields back when applying a server
/// acknowledgement or tombstone — without knowing the concrete type. Adding a
/// new synced resource therefore costs one ``SyncResourceAdapter``, not a copy
/// of the state machine.
///
/// A conforming type typically stores these fields directly (for example, a
/// SwiftData `@Model` class), so conformance can often be declared with an empty
/// extension.
public protocol SyncableModel: AnyObject {
    /// Server primary key once the row has been accepted by the backend.
    var serverId: Int? { get set }
    /// Last server `updatedAt` observed for this row.
    var updatedAt: Date { get set }
    /// Local soft-delete tombstone.
    ///
    /// - Important: Do not name the backing stored property `isDeleted` on a
    ///   SwiftData `@Model`; that name is shadowed by `PersistentModel.isDeleted`
    ///   (the context's hard-delete state), so writes won't read back. Use a
    ///   distinct name such as `isTombstoned`.
    var isTombstoned: Bool { get set }
    /// Local dirty-state marker.
    var syncState: SyncState { get set }
    /// Wall-clock of the last local mutation; the ack-guard pivot.
    var localUpdatedAt: Date { get set }
}
