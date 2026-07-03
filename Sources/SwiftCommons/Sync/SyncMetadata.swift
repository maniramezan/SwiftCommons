import Foundation
import SwiftData

/// Per-resource cursor and server-config cache for the ``SyncEngine``.
///
/// One row is stored per resource name. The engine keeps the delta ``cursor``
/// here between passes, and stashes any server-supplied passthrough values in
/// ``serverInfo`` so the app can read policy fields (for example, quota limits)
/// without the engine having to know about them.
@Model
public final class SyncMetadata {
    /// Creates a metadata row for a resource.
    /// - Parameters:
    ///   - resourceName: Stable identifier for the resource (matches
    ///     ``SyncResourceAdapter/resourceName``).
    ///   - cursor: Opaque server delta cursor, if one has been received.
    ///   - syncVersion: Server sync-protocol version last observed.
    ///   - lastSyncedAt: Timestamp of the last successful pass.
    ///   - serverInfo: App-defined passthrough values from the last response.
    public init(
        resourceName: String,
        cursor: String? = nil,
        syncVersion: Int = 1,
        lastSyncedAt: Date? = nil,
        serverInfo: [String: String] = [:]
    ) {
        self.resourceName = resourceName
        self.cursor = cursor
        self.syncVersion = syncVersion
        self.lastSyncedAt = lastSyncedAt
        self.serverInfo = serverInfo
    }

    /// Stable identifier for the resource this row tracks.
    @Attribute(.unique) public var resourceName: String
    /// Opaque server delta cursor, or `nil` before the first successful pass.
    public var cursor: String?
    /// Server sync-protocol version last observed.
    public var syncVersion: Int
    /// Timestamp of the last successful sync pass.
    public var lastSyncedAt: Date?
    /// App-defined passthrough values copied from the last server response.
    public var serverInfo: [String: String]
}
