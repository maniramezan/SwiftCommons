import Foundation

/// Resource-specific glue for the generic loop in ``SyncEngine``.
///
/// Build one adapter per resource. The contract logic — ack guard, pending
/// guard, full-snapshot reconciliation, pagination drain, and full-resync
/// recovery — lives in the engine, so it holds identically for every resource
/// and a new resource cannot accidentally skip one. The adapter only supplies
/// the resource specifics: how to fetch and key local rows, how to build the
/// wire payloads, how to call the transport, and how to apply server changes.
///
/// - `Model`: the local ``SyncableModel`` type (a class or a value type).
/// - `Upsert`/`Delete`: the app's wire shapes for pushed changes.
/// - `Change`: the app's wire shape for a server-side change.
/// - `Context`: the ``SyncStore/Context`` the row closures read and write through.
///
/// Every closure except ``call`` runs inside one of the store's transactions, wherever the
/// store runs it, so they must not touch state isolated to another actor. ``call`` runs outside
/// any transaction; to reach main-actor state from it, write it as
/// `{ @MainActor request in … }`.
public struct SyncResourceAdapter<
    Model: SyncableModel,
    Upsert: Encodable & Sendable,
    Delete: Encodable & Sendable,
    Change: Decodable & Sendable,
    Context
>: Sendable {
    /// Creates an adapter from its resource-specific closures.
    ///
    /// Each closure parameter is stored in the property of the same name; the optional
    /// `findExistingBatch` defaults to `nil`.
    public init(
        resourceName: String,
        fetchPending: @escaping @Sendable (Context) throws -> [Model],
        businessKey: @escaping @Sendable (Model) -> String,
        makeUpserts: @escaping @Sendable ([Model]) -> [Upsert],
        makeDeletes: @escaping @Sendable ([Model]) -> [Delete],
        call:
            @escaping @Sendable (SyncRequestDTO<Upsert, Delete>) async throws ->
            SyncResponseDTO<Change>,
        findExisting: @escaping @Sendable (Change, Context) throws -> Model?,
        changeKey: @escaping @Sendable (Change) -> String?,
        isChangeDeleted: @escaping @Sendable (Change) -> Bool,
        upsertFromChange: @escaping @Sendable (Change, Model?, Context) throws -> Void,
        fetchActive: @escaping @Sendable (Context) throws -> [Model],
        purgeSynced: @escaping @Sendable (Context) throws -> Void,
        persist: @escaping @Sendable (Model, Context) throws -> Void,
        findExistingBatch: (@Sendable ([Change], Context) throws -> [String: Model])? = nil
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
        self.persist = persist
        self.findExistingBatch = findExistingBatch
    }

    /// Stable identifier for the resource; also keys its ``SyncCheckpoint``.
    public let resourceName: String
    /// Fetches rows with un-pushed local changes.
    public let fetchPending: @Sendable (Context) throws -> [Model]
    /// Canonical business key; MUST match the server's `applied[].key` and ``changeKey``.
    public let businessKey: @Sendable (Model) -> String
    /// Builds the upsert payloads for the pending rows.
    public let makeUpserts: @Sendable ([Model]) -> [Upsert]
    /// Builds the delete payloads for the pending rows.
    public let makeDeletes: @Sendable ([Model]) -> [Delete]
    /// Sends a request and returns the server response (the transport seam).
    ///
    /// Runs outside any store transaction.
    public let call:
        @Sendable (SyncRequestDTO<Upsert, Delete>) async throws -> SyncResponseDTO<Change>
    /// Finds the local row a server change refers to, if any.
    public let findExisting: @Sendable (Change, Context) throws -> Model?
    /// Finds the local rows for a whole page of server changes in one fetch.
    ///
    /// When set, the engine calls it once per page instead of calling ``findExisting`` once per
    /// change, which turns a 100-change page from 100 fetches into one. The returned dictionary
    /// is keyed by ``changeKey``; changes without a key, and changes whose key already appeared
    /// earlier on the same page, still use ``findExisting`` so rows inserted mid-page are found.
    /// Leave it `nil` to look rows up one at a time.
    public let findExistingBatch: (@Sendable ([Change], Context) throws -> [String: Model])?
    /// Active-row key for a change, or `nil` if the change can't contribute one.
    public let changeKey: @Sendable (Change) -> String?
    /// Whether a server change represents a deletion.
    public let isChangeDeleted: @Sendable (Change) -> Bool
    /// Applies a server change onto the existing row (or inserts a new one) and writes it.
    ///
    /// Throwing rolls back the whole page, including its checkpoint.
    public let upsertFromChange: @Sendable (Change, Model?, Context) throws -> Void
    /// Fetches every non-tombstoned row, for full-snapshot reconciliation.
    public let fetchActive: @Sendable (Context) throws -> [Model]
    /// Deletes synced rows before a full resync.
    public let purgeSynced: @Sendable (Context) throws -> Void
    /// Writes back a row the engine changed — an applied acknowledgement or a reconciliation
    /// tombstone.
    ///
    /// SQL stores update the row here. For live-object stores such as SwiftData the engine's
    /// changes already land on the managed object, so this is a no-op.
    public let persist: @Sendable (Model, Context) throws -> Void
}
