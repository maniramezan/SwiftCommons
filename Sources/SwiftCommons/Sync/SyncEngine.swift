import Foundation
import OSLog

/// Drives offline, cross-device sync for locally-stored resources through one
/// generic loop.
///
/// Resources plug in as ``SyncResourceAdapter`` values; the engine owns the
/// contract invariants — ack guard, pending guard, full-snapshot
/// reconciliation, pagination drain, and full-resync recovery — so they hold
/// identically for every resource. Sync one resource with ``sync(_:)`` or a set
/// with ``syncAll(_:)``.
///
/// The engine is not tied to an actor or a persistence framework: every local read
/// and write goes through the ``SyncStore``'s transactions, which run wherever the
/// store chooses, and only `Sendable` values cross the network calls between them.
/// Each page's rows and its ``SyncCheckpoint`` commit in one transaction.
///
/// Passes are serialized by an ``AsyncLock`` so overlapping triggers can't
/// double-apply; inject a shared lock when several engine instances must serialize
/// together.
public final class SyncEngine<Store: SyncStore>: Sendable {

    /// Creates a sync engine over a store.
    /// - Parameters:
    ///   - store: Where synced rows and checkpoints live.
    ///   - limit: Maximum number of server changes requested per page.
    ///   - lock: Serializes passes. Share one instance across engines that must
    ///     not run concurrently.
    ///   - events: Handler for ``SyncEvent`` lifecycle events.
    ///   - logger: Logger for failures and pass tracing.
    public init(
        store: Store,
        limit: Int = 100,
        lock: AsyncLock = AsyncLock(),
        events: @escaping @Sendable (SyncEvent) async -> Void = { _ in },
        logger: Logger = .swiftCommonsLogger(category: "SyncEngine")
    ) {
        precondition(limit > 0, "limit must be greater than 0")
        self.store = store
        self.limit = limit
        self.lock = lock
        eventsTrack = events
        self.logger = logger
    }

    /// The store this engine reads and writes through.
    public let store: Store

    /// Runs one sync pass for a single resource, under the serial lock.
    public func sync<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>
    ) async throws {
        try await locked { try await self.drive(adapter) }
    }

    /// Runs a pass for each resource under one held lock.
    ///
    /// Resources are isolated: a failure in one does not prevent the others from
    /// running. The first error seen is thrown after all resources are attempted.
    public func syncAll(_ resources: [AnySyncResource<Store>]) async throws {
        try await locked {
            var firstError: Error?
            for resource in resources {
                do {
                    try await resource.run(self)
                } catch {
                    self.logger.error(
                        "Sync resource failed", error: error,
                        context: "resource=\(resource.resourceName)")
                    if firstError == nil { firstError = error }
                }
            }
            if let firstError { throw firstError }
        }
    }

    // MARK: Internal

    let limit: Int
    let logger: Logger

    /// Runs `op` while holding the serial lock, releasing on both success and throw.
    func locked(_ op: () async throws -> Void) async throws {
        await lock.lock()
        do {
            try await op()
            await lock.unlock()
        } catch {
            await lock.unlock()
            throw error
        }
    }

    func track(_ event: SyncEvent) async { await eventsTrack(event) }

    // MARK: Private

    private let lock: AsyncLock
    private let eventsTrack: @Sendable (SyncEvent) async -> Void
}

// MARK: - Errors

/// Thrown when the server keeps reporting more pages without making progress.
enum SyncPaginationError: Error, Equatable, LocalizedError {
    /// A page reported `hasMore` with the cursor it was requested with and no changes.
    case stalledCursor(resource: String)

    var errorDescription: String? {
        switch self {
        case .stalledCursor(let resource):
            "Sync for \(resource) stopped: the server reported more pages without advancing the cursor."
        }
    }
}

// MARK: - Engine

extension SyncEngine {

    /// What the first transaction hands to the push call.
    private struct Outbound<Upsert: Encodable & Sendable, Delete: Encodable & Sendable>: Sendable {
        let request: SyncRequestDTO<Upsert, Delete>
        /// `localUpdatedAt` of each pushed row at send time, keyed by business key.
        let sentVersions: [String: Date]
    }

    /// What one committed page hands back to the drain loop.
    private struct PageOutcome: Sendable {
        let activeKeys: Set<String>
        let isFull: Bool
        /// Acknowledgements that marked a row blocked; reported once the page commits.
        let blocked: [SyncAppliedDTO]
    }

    /// One sync pass for one resource. Owns the whole contract; resource
    /// specifics come from `adapter`.
    func drive<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>
    ) async throws {
        let resource = adapter.resourceName
        await track(.started(resource: resource))
        let startedAt = Date()
        do {
            let outbound = try await store.transaction { context in
                let checkpoint = try self.store.checkpoint(for: resource, in: context)
                let pending = try adapter.fetchPending(context)
                var sentVersions: [String: Date] = [:]
                for row in pending {
                    let key = adapter.businessKey(row)
                    if sentVersions[key] == nil { sentVersions[key] = row.localUpdatedAt }
                }
                return Outbound(
                    request: SyncRequestDTO(
                        since: checkpoint?.cursor,
                        limit: self.limit,
                        upserts: adapter.makeUpserts(pending),
                        deletes: adapter.makeDeletes(pending)
                    ),
                    sentVersions: sentVersions
                )
            }
            logger.debug(
                "Sync push for \(resource, privacy: .public): \(outbound.sentVersions.count) pending"
            )

            var response = try await adapter.call(outbound.request)
            // Acks arrive on the push response. A full resync replaces that response, so keep
            // its acks and apply them together with any on the resync response.
            var applied = response.applied
            if response.fullResyncRequired {
                response = try await fullResync(adapter)
                applied += response.applied
            }

            let firstPage = response
            let acks = applied
            var outcome = try await store.transaction { context in
                let blocked = try self.applyAcks(
                    acks, sentVersions: outbound.sentVersions, adapter: adapter, context: context)
                return try self.commitPage(
                    firstPage, activeKeys: [], sawFull: false, blocked: blocked,
                    adapter: adapter, context: context)
            }
            await reportBlocked(outcome.blocked, resource: resource)
            var sawFull = outcome.isFull
            var changeCount = response.serverChanges.count
            logger.debug(
                "Sync page committed for \(resource, privacy: .public): \(response.serverChanges.count) changes, \(applied.count) acks"
            )

            while response.hasMore {
                try Task.checkCancellation()
                let requestedCursor = response.cursor
                response = try await adapter.call(
                    SyncRequestDTO(
                        since: requestedCursor, limit: limit, upserts: [], deletes: [])
                )
                // A page that claims more data but neither advances the cursor nor carries
                // changes would be requested again unchanged, forever.
                if response.hasMore && response.cursor == requestedCursor
                    && response.serverChanges.isEmpty
                {
                    throw SyncPaginationError.stalledCursor(resource: resource)
                }
                let page = response
                let activeKeys = outcome.activeKeys
                let sawFullSoFar = sawFull
                outcome = try await store.transaction { context in
                    try self.commitPage(
                        page, activeKeys: activeKeys, sawFull: sawFullSoFar, blocked: [],
                        adapter: adapter, context: context)
                }
                sawFull = outcome.isFull || sawFull
                changeCount += response.serverChanges.count
                logger.debug(
                    "Sync page committed for \(resource, privacy: .public): \(response.serverChanges.count) changes"
                )
            }

            if sawFull {
                let activeKeys = outcome.activeKeys
                let finalCursor = response.cursor
                let tombstoned = try await store.transaction { context in
                    let tombstoned = try self.reconcileFullSnapshot(
                        adapter, activeKeys: activeKeys, context: context)
                    var checkpoint =
                        try self.store.checkpoint(for: resource, in: context) ?? SyncCheckpoint()
                    checkpoint.cursor = finalCursor
                    try self.store.saveCheckpoint(checkpoint, for: resource, in: context)
                    return tombstoned
                }
                logger.debug(
                    "Sync snapshot reconciled for \(resource, privacy: .public): \(tombstoned) tombstoned"
                )
            }

            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            await track(
                .completed(
                    resource: resource,
                    mode: response.mode,
                    applied: applied.count,
                    serverChanges: changeCount,
                    durationMs: durationMs
                )
            )
        } catch {
            logger.error("Sync failed", error: error, context: "resource=\(resource)")
            await track(
                .failed(
                    resource: resource,
                    errorType: String(describing: type(of: error)),
                    message: error.localizedDescription
                )
            )
            throw error
        }
    }

    /// Applies acknowledgements to the rows that are still pending, and returns the ones that
    /// marked a row blocked.
    ///
    /// Ack guard: rows are re-read inside the transaction and an ack only lands when the row's
    /// `localUpdatedAt` still equals the value it was pushed with. A row edited, or hard-deleted,
    /// while the request was in flight is skipped and re-pushes next pass.
    private func applyAcks<Model, Upsert, Delete, Change>(
        _ applied: [SyncAppliedDTO],
        sentVersions: [String: Date],
        adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>,
        context: Store.Context
    ) throws -> [SyncAppliedDTO] {
        guard !applied.isEmpty else { return [] }
        var pendingByKey: [String: Model] = [:]
        for row in try adapter.fetchPending(context) {
            let key = adapter.businessKey(row)
            if pendingByKey[key] == nil { pendingByKey[key] = row }
        }
        var blocked: [SyncAppliedDTO] = []
        for status in applied {
            guard var model = pendingByKey[status.key] else { continue }
            guard sentVersions[status.key] == model.localUpdatedAt else { continue }
            apply(status, to: &model)
            try adapter.persist(model, context)
            pendingByKey[status.key] = model
            if status.statusKind == .blocked || status.statusKind == .rejected {
                blocked.append(status)
            }
        }
        return blocked
    }

    private func apply<Model: SyncableModel>(_ status: SyncAppliedDTO, to model: inout Model) {
        if let id = status.id { model.serverId = id }
        if let updatedAt = status.updatedAt {
            model.updatedAt = Date(timeIntervalSince1970: updatedAt)
        }
        switch status.statusKind {
        case .blocked, .rejected:
            model.syncState = .blocked
        case .deleted:
            model.syncState = .synced
            model.isTombstoned = true
        case .created, .updated, .noop:
            model.syncState = .synced
            model.isTombstoned = false
        case .unknown:
            break
        }
    }

    /// Ingests one page and writes its checkpoint in the caller's transaction.
    ///
    /// While draining a full snapshot the cursor is held back until every page has been
    /// ingested and reconciled: if a later page fails, the next pass restarts the snapshot
    /// instead of resuming as a delta and never reconciling rows absent from it.
    private func commitPage<Model, Upsert, Delete, Change>(
        _ response: SyncResponseDTO<Change>,
        activeKeys: Set<String>,
        sawFull: Bool,
        blocked: [SyncAppliedDTO],
        adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>,
        context: Store.Context
    ) throws -> PageOutcome {
        var activeKeys = activeKeys
        let isFull = try ingest(adapter, response, into: &activeKeys, context: context)
        var checkpoint =
            try store.checkpoint(for: adapter.resourceName, in: context) ?? SyncCheckpoint()
        if !(isFull || sawFull) {
            checkpoint.cursor = response.cursor
        }
        checkpoint.syncVersion = response.syncVersion
        if let serverInfo = response.serverInfo {
            checkpoint.serverInfo = serverInfo
        }
        checkpoint.lastSyncedAt = Date()
        try store.saveCheckpoint(checkpoint, for: adapter.resourceName, in: context)
        return PageOutcome(activeKeys: activeKeys, isFull: isFull, blocked: blocked)
    }

    /// Applies one page's `serverChanges`; returns whether the page was a full snapshot.
    private func ingest<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>,
        _ response: SyncResponseDTO<Change>,
        into activeKeys: inout Set<String>,
        context: Store.Context
    ) throws -> Bool {
        let batch = try adapter.findExistingBatch?(response.serverChanges, context)
        var seenKeys = Set<String>()
        for change in response.serverChanges {
            let key = adapter.changeKey(change)
            if !adapter.isChangeDeleted(change), let key {
                activeKeys.insert(key)
            }
            let existing: Model?
            // A key repeated on one page may refer to a row the earlier change just inserted,
            // which the batch snapshot can't contain, so look that one up directly.
            if let batch, let key, seenKeys.insert(key).inserted {
                existing = batch[key]
            } else {
                existing = try adapter.findExisting(change, context)
            }
            // Pending guard: never clobber a row that still has un-pushed local changes.
            if let existing, existing.syncState != .synced { continue }
            try adapter.upsertFromChange(change, existing, context)
        }
        return response.modeKind == .full
    }

    /// Tombstones clean rows absent from the snapshot; returns how many it tombstoned.
    private func reconcileFullSnapshot<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>,
        activeKeys: Set<String>,
        context: Store.Context
    ) throws -> Int {
        var tombstoned = 0
        for var row in try adapter.fetchActive(context) where !row.isTombstoned {
            // Tombstone guard: only clean rows absent from the snapshot; never delete
            // rows with un-pushed local changes.
            if row.syncState == .synced, !activeKeys.contains(adapter.businessKey(row)) {
                row.isTombstoned = true
                row.syncState = .synced
                try adapter.persist(row, context)
                tombstoned += 1
            }
        }
        return tombstoned
    }

    /// Cursor too old to serve a delta: drop clean rows + cursor, then pull a fresh snapshot.
    private func fullResync<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>
    ) async throws -> SyncResponseDTO<Change> {
        let resource = adapter.resourceName
        try await store.transaction { context in
            try adapter.purgeSynced(context)
            var checkpoint =
                try self.store.checkpoint(for: resource, in: context) ?? SyncCheckpoint()
            checkpoint.cursor = nil
            try self.store.saveCheckpoint(checkpoint, for: resource, in: context)
        }
        logger.debug("Sync full resync purged \(resource, privacy: .public)")
        await track(.fullResyncStarted(resource: resource))
        return try await adapter.call(
            SyncRequestDTO(since: nil, limit: limit, upserts: [], deletes: [])
        )
    }

    private func reportBlocked(_ blocked: [SyncAppliedDTO], resource: String) async {
        for status in blocked {
            await track(
                .itemBlocked(resource: resource, status: status.status, reason: status.reason))
        }
    }
}

// MARK: - Type erasure

/// A type-erased ``SyncResourceAdapter`` for use with ``SyncEngine/syncAll(_:)``.
///
/// Adapters are generic over their model and wire types, so a heterogeneous list can't
/// name a single adapter type. Wrap each adapter in an `AnySyncResource` to sync
/// them together; every wrapped adapter must use the same store's `Context`.
public struct AnySyncResource<Store: SyncStore>: Sendable {
    /// Erases a concrete adapter.
    public init<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change, Store.Context>
    ) {
        resourceName = adapter.resourceName
        run = { try await $0.drive(adapter) }
    }

    /// Stable identifier for the wrapped resource.
    public let resourceName: String

    let run: @Sendable (SyncEngine<Store>) async throws -> Void
}
