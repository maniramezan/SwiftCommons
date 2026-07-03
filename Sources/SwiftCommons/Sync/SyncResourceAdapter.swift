import Foundation
import SwiftData

/// Resource-specific glue for the generic loop in ``SyncEngine``.
///
/// Build one adapter per resource. The contract logic — ack guard, pending
/// guard, full-snapshot reconciliation, pagination drain, and full-resync
/// recovery — lives in the engine, so it holds identically for every resource
/// and a new resource cannot accidentally skip one. The adapter only supplies
/// the resource specifics: how to fetch and key local rows, how to build the
/// wire payloads, how to call the transport, and how to apply server changes.
///
/// - `Model`: the local ``SyncableModel`` type.
/// - `Upsert`/`Delete`: the app's wire shapes for pushed changes.
/// - `Change`: the app's wire shape for a server-side change.
@MainActor
public struct SyncResourceAdapter<
    Model: SyncableModel,
    Upsert: Encodable & Sendable,
    Delete: Encodable & Sendable,
    Change: Decodable & Sendable
> {
    /// Creates an adapter from its resource-specific closures.
    public init(
        resourceName: String,
        fetchPending: @escaping (ModelContext) throws -> [Model],
        businessKey: @escaping (Model) -> String,
        makeUpserts: @escaping ([Model]) -> [Upsert],
        makeDeletes: @escaping ([Model]) -> [Delete],
        call: @escaping (SyncRequestDTO<Upsert, Delete>) async throws -> SyncResponseDTO<Change>,
        findExisting: @escaping (Change, ModelContext) throws -> Model?,
        changeKey: @escaping (Change) -> String?,
        isChangeDeleted: @escaping (Change) -> Bool,
        upsertFromChange: @escaping (Change, Model?, ModelContext) -> Void,
        fetchActive: @escaping (ModelContext) throws -> [Model],
        purgeSynced: @escaping (ModelContext) throws -> Void
    ) {
        self.resourceName = resourceName
        self.fetchPending = fetchPending
        self.businessKey = businessKey
        self.makeUpserts = makeUpserts
        self.makeDeletes = makeDeletes
        self.call = call
        self.findExisting = findExisting
        self.changeKey = changeKey
        self.isChangeDeleted = isChangeDeleted
        self.upsertFromChange = upsertFromChange
        self.fetchActive = fetchActive
        self.purgeSynced = purgeSynced
    }

    /// Stable identifier for the resource; also keys its ``SyncMetadata`` row.
    public let resourceName: String
    /// Fetches rows with un-pushed local changes.
    public let fetchPending: (ModelContext) throws -> [Model]
    /// Canonical business key; MUST match the server's `applied[].key` and ``changeKey``.
    public let businessKey: (Model) -> String
    /// Builds the upsert payloads for the pending rows.
    public let makeUpserts: ([Model]) -> [Upsert]
    /// Builds the delete payloads for the pending rows.
    public let makeDeletes: ([Model]) -> [Delete]
    /// Sends a request and returns the server response (the transport seam).
    public let call: (SyncRequestDTO<Upsert, Delete>) async throws -> SyncResponseDTO<Change>
    /// Finds the local row a server change refers to, if any.
    public let findExisting: (Change, ModelContext) throws -> Model?
    /// Active-row key for a change, or `nil` if the change can't contribute one.
    public let changeKey: (Change) -> String?
    /// Whether a server change represents a deletion.
    public let isChangeDeleted: (Change) -> Bool
    /// Applies a server change onto the existing row (or inserts a new one).
    public let upsertFromChange: (Change, Model?, ModelContext) -> Void
    /// Fetches every non-tombstoned row, for full-snapshot reconciliation.
    public let fetchActive: (ModelContext) throws -> [Model]
    /// Deletes synced rows before a full resync.
    public let purgeSynced: (ModelContext) throws -> Void
}
