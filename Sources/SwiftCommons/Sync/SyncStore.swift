import Foundation

/// A resource's sync position, persisted by a ``SyncStore`` between passes.
///
/// The ``SyncEngine`` reads the checkpoint at the start of a pass to request the next delta, and
/// writes it back inside the same transaction that commits each page's rows, so the stored
/// cursor never runs ahead of (or behind) the data it describes.
public struct SyncCheckpoint: Sendable, Equatable {
    /// Creates a checkpoint.
    /// - Parameters:
    ///   - cursor: Opaque server delta cursor, if one has been received.
    ///   - syncVersion: Server sync-protocol version last observed.
    ///   - lastSyncedAt: Timestamp of the last committed page.
    ///   - serverInfo: App-defined passthrough values from the last response that carried them.
    public init(
        cursor: String? = nil,
        syncVersion: Int = 1,
        lastSyncedAt: Date? = nil,
        serverInfo: [String: String] = [:]
    ) {
        self.cursor = cursor
        self.syncVersion = syncVersion
        self.lastSyncedAt = lastSyncedAt
        self.serverInfo = serverInfo
    }

    /// Opaque server delta cursor, or `nil` before the first committed pass.
    public var cursor: String?
    /// Server sync-protocol version last observed.
    public var syncVersion: Int
    /// Timestamp of the last committed page.
    public var lastSyncedAt: Date?
    /// App-defined passthrough values copied from the last server response that carried them.
    public var serverInfo: [String: String]
}

/// The persistence seam behind ``SyncEngine``: where synced rows and checkpoints live, and how
/// a group of writes commits atomically.
///
/// The engine never holds a store handle or a model across a network call. Each step of a pass
/// that touches local data runs inside one ``transaction(_:)``, and only `Sendable` values
/// (request and response DTOs, sent versions, keys) cross the `await` between steps. That keeps
/// the seam usable by object-graph stores (SwiftData, Core Data) and by SQL stores whose rows are
/// value types and whose write handle only exists inside a transaction (GRDB, raw SQLite).
///
/// The store, not the engine, decides isolation: ``transaction(_:)`` runs `body` wherever the
/// store keeps its connection or context — the main actor, a private actor, or a serial queue.
///
/// SwiftData stores ship behind the default `SwiftData` trait. For any other store, implement
/// this protocol and give each ``SyncResourceAdapter`` a ``SyncResourceAdapter/persist`` closure
/// that writes a modified row back through the `Context`.
public protocol SyncStore: Sendable {
    /// The handle adapters use to read and write rows inside a transaction — for example a
    /// SwiftData `ModelContext` or a SQL database connection.
    associatedtype Context

    /// Runs `body` as one atomic unit in the store's own isolation, then commits.
    ///
    /// Row writes and checkpoint writes made through `context` must commit together, or not
    /// at all when `body` throws. `body` is synchronous, so a write transaction can never span
    /// a network call.
    func transaction<T: Sendable>(_ body: @Sendable (Context) throws -> T) async throws -> T

    /// Reads the stored checkpoint for a resource, or `nil` before its first committed page.
    func checkpoint(for resourceName: String, in context: Context) throws -> SyncCheckpoint?

    /// Writes the checkpoint for a resource through the transaction's `context`.
    func saveCheckpoint(
        _ checkpoint: SyncCheckpoint, for resourceName: String, in context: Context) throws
}
