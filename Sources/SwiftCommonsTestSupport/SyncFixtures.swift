import Foundation
import SwiftCommons
import SwiftData

/// Creates an in-memory `ModelContainer` for testing a ``SwiftCommons/SyncEngine``.
///
/// ``SwiftCommons/SyncMetadata`` is added to `types` automatically, since the engine
/// stores each resource's cursor there and fails at runtime if the schema lacks it:
///
///     let container = try makeInMemorySyncContainer(for: Item.self)
///     let engine = SyncEngine(modelContainer: container)
///
/// - Parameter types: The app's synced `PersistentModel` types.
/// - Returns: A fresh, isolated in-memory container.
/// - Throws: Any error thrown by `ModelContainer.init(for:configurations:)`.
public func makeInMemorySyncContainer(
    for types: any PersistentModel.Type...
) throws -> ModelContainer {
    let allTypes: [any PersistentModel.Type] = types + [SyncMetadata.self]
    return try ModelContainer.make(for: allTypes, inMemory: true)
}

extension SyncResponseDTO {

    /// Builds a response with test-friendly defaults: a single delta page with no
    /// acknowledgements or changes.
    ///
    ///     let adapter = SyncResourceAdapter(
    ///         // ...
    ///         call: recordingCall(
    ///             returning: SyncResponseDTO<ItemChange>.fixture(
    ///                 applied: [.fixture(key: "run", id: 101, status: "created")],
    ///                 cursor: "cursor-1"
    ///             ),
    ///             into: requests
    ///         ),
    ///         // ...
    ///     )
    public static func fixture(
        syncVersion: Int = 1,
        mode: String = "delta",
        applied: [SyncAppliedDTO] = [],
        serverChanges: [Change] = [],
        cursor: String? = nil,
        hasMore: Bool = false,
        fullResyncRequired: Bool = false,
        serverInfo: [String: String]? = nil
    ) -> SyncResponseDTO {
        SyncResponseDTO(
            syncVersion: syncVersion,
            mode: mode,
            applied: applied,
            serverChanges: serverChanges,
            cursor: cursor,
            hasMore: hasMore,
            fullResyncRequired: fullResyncRequired,
            serverInfo: serverInfo
        )
    }
}

extension SyncAppliedDTO {

    /// Builds an acknowledgement with test-friendly defaults.
    ///
    /// - Parameters:
    ///   - key: Business key matching the pushed row.
    ///   - id: Assigned server id. Defaults to `nil`.
    ///   - status: Server outcome (`created`, `updated`, `deleted`, `noop`, `blocked`,
    ///     `rejected`). Defaults to `"updated"`.
    ///   - updatedAt: Server `updatedAt` in seconds since 1970. Defaults to `nil`.
    ///   - reason: Reason for a block or rejection. Defaults to `nil`.
    public static func fixture(
        key: String,
        id: Int? = nil,
        status: String = "updated",
        updatedAt: TimeInterval? = nil,
        reason: String? = nil
    ) -> SyncAppliedDTO {
        SyncAppliedDTO(key: key, id: id, status: status, updatedAt: updatedAt, reason: reason)
    }
}
