import Foundation
import OSLog
import SwiftData

/// Drives offline, cross-device sync for locally-stored resources through one
/// generic loop.
///
/// Resources plug in as ``SyncResourceAdapter`` values; the engine owns the
/// contract invariants — ack guard, pending guard, full-snapshot
/// reconciliation, pagination drain, and full-resync recovery — so they hold
/// identically for every resource. Sync one resource with ``sync(_:)`` or a set
/// with ``syncAll(_:)``.
///
/// The engine is `@MainActor` and mutates the container's `mainContext`. Passes
/// are serialized by an ``AsyncLock`` so overlapping triggers can't double-apply;
/// inject a shared lock when several engine instances must serialize together.
@MainActor
public final class SyncEngine {

    /// Creates a sync engine.
    /// - Parameters:
    ///   - modelContainer: The SwiftData container whose `mainContext` holds the
    ///     synced rows and ``SyncMetadata``.
    ///   - limit: Maximum number of server changes requested per page.
    ///   - lock: Serializes passes. Share one instance across engines that must
    ///     not run concurrently.
    ///   - events: Handler for ``SyncEvent`` lifecycle events.
    ///   - logger: Logger for failures.
    public nonisolated init(
        modelContainer: ModelContainer,
        limit: Int = 100,
        lock: AsyncLock = AsyncLock(),
        events: @escaping @Sendable (SyncEvent) async -> Void = { _ in },
        logger: Logger = .swiftCommonsLogger(for: SyncEngine.self)
    ) {
        self.modelContainer = modelContainer
        self.limit = limit
        self.lock = lock
        eventsTrack = events
        self.logger = logger
    }

    /// Runs one sync pass for a single resource, under the serial lock.
    public func sync<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>
    ) async throws {
        try await locked { try await self.drive(adapter) }
    }

    /// Runs a pass for each resource under one held lock.
    ///
    /// Resources are isolated: a failure in one does not prevent the others from
    /// running. The first error seen is thrown after all resources are attempted.
    public func syncAll(_ resources: [AnySyncResource]) async throws {
        try await locked {
            var firstError: Error?
            for resource in resources {
                do {
                    try await resource.run(self)
                } catch {
                    self.logger.error("Sync resource failed", error: error)
                    if firstError == nil { firstError = error }
                }
            }
            if let firstError { throw firstError }
        }
    }

    // MARK: Internal

    let modelContainer: ModelContainer
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

    func metadata(for resourceName: String, in context: ModelContext) throws -> SyncMetadata {
        var descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.resourceName == resourceName }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let metadata = SyncMetadata(resourceName: resourceName)
        context.insert(metadata)
        return metadata
    }

    func update<Change>(_ metadata: SyncMetadata, with response: SyncResponseDTO<Change>) {
        metadata.cursor = response.cursor
        metadata.syncVersion = response.syncVersion
        if let serverInfo = response.serverInfo {
            metadata.serverInfo = serverInfo
        }
        metadata.lastSyncedAt = Date()
    }

    // MARK: Private

    private let lock: AsyncLock
    private let eventsTrack: @Sendable (SyncEvent) async -> Void
}

// MARK: - Engine

extension SyncEngine {

    /// One sync pass for one resource. Owns the whole contract; resource
    /// specifics come from `adapter`.
    func drive<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>
    ) async throws {
        let resource = adapter.resourceName
        await track(.started(resource: resource))
        let startedAt = Date()
        do {
            let context = modelContainer.mainContext
            let metadata = try metadata(for: resource, in: context)
            let pending = try adapter.fetchPending(context)
            let sentVersions = Dictionary(
                pending.map { (adapter.businessKey($0), $0.localUpdatedAt) },
                uniquingKeysWith: { first, _ in first }
            )
            let pendingByKey = Dictionary(
                pending.map { (adapter.businessKey($0), $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var response = try await adapter.call(
                SyncRequestDTO(
                    since: metadata.cursor,
                    limit: limit,
                    upserts: adapter.makeUpserts(pending),
                    deletes: adapter.makeDeletes(pending)
                )
            )
            if response.fullResyncRequired {
                response = try await fullResync(adapter, metadata: metadata, context: context)
            }

            await applyAck(
                response.applied,
                pendingByKey: pendingByKey,
                sentVersions: sentVersions,
                resource: resource
            )

            var activeKeys = Set<String>()
            var sawFull = try ingest(adapter, response, into: &activeKeys, context: context)
            update(metadata, with: response)
            try context.save()
            var changeCount = response.serverChanges.count

            while response.hasMore {
                response = try await adapter.call(
                    SyncRequestDTO(since: metadata.cursor, limit: limit, upserts: [], deletes: [])
                )
                sawFull =
                    try ingest(adapter, response, into: &activeKeys, context: context) || sawFull
                update(metadata, with: response)
                try context.save()
                changeCount += response.serverChanges.count
            }

            if sawFull {
                try reconcileFullSnapshot(adapter, activeKeys: activeKeys, context: context)
                try context.save()
            }

            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            await track(
                .completed(
                    resource: resource,
                    mode: response.mode,
                    applied: response.applied.count,
                    serverChanges: changeCount,
                    durationMs: durationMs
                )
            )
        } catch {
            logger.error("Sync failed for \(resource)", error: error)
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

    private func applyAck<Model: SyncableModel>(
        _ applied: [SyncAppliedDTO],
        pendingByKey: [String: Model],
        sentVersions: [String: Date],
        resource: String
    ) async {
        for status in applied {
            guard let model = pendingByKey[status.key] else { continue }
            // Ack guard: skip if the row was edited mid-flight; it re-pushes next sync.
            guard sentVersions[status.key] == model.localUpdatedAt else { continue }
            apply(status, to: model)
            if status.status == "blocked" || status.status == "rejected" {
                await track(
                    .itemBlocked(resource: resource, status: status.status, reason: status.reason)
                )
            }
        }
    }

    private func apply(_ status: SyncAppliedDTO, to model: any SyncableModel) {
        if let id = status.id { model.serverId = id }
        if let updatedAt = status.updatedAt {
            model.updatedAt = Date(timeIntervalSince1970: updatedAt)
        }
        switch status.status {
        case "blocked", "rejected":
            model.syncState = .blocked
        case "deleted":
            model.syncState = .synced
            model.isTombstoned = true
        case "created", "updated", "noop":
            model.syncState = .synced
            model.isTombstoned = false
        default:
            break
        }
    }

    /// Applies one page's `serverChanges`; returns whether the page was a full snapshot.
    private func ingest<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>,
        _ response: SyncResponseDTO<Change>,
        into activeKeys: inout Set<String>,
        context: ModelContext
    ) throws -> Bool {
        for change in response.serverChanges {
            if !adapter.isChangeDeleted(change), let key = adapter.changeKey(change) {
                activeKeys.insert(key)
            }
            let existing = try adapter.findExisting(change, context)
            // Pending guard: never clobber a row that still has un-pushed local changes.
            if let existing, existing.syncState != .synced { continue }
            adapter.upsertFromChange(change, existing, context)
        }
        return response.mode == "full"
    }

    private func reconcileFullSnapshot<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>,
        activeKeys: Set<String>,
        context: ModelContext
    ) throws {
        for row in try adapter.fetchActive(context) where !row.isTombstoned {
            // Tombstone guard: only clean rows absent from the snapshot; never delete
            // rows with un-pushed local changes.
            if row.syncState == .synced, !activeKeys.contains(adapter.businessKey(row)) {
                row.isTombstoned = true
                row.syncState = .synced
            }
        }
    }

    /// Cursor too old to serve a delta: drop clean rows + cursor, then pull a fresh snapshot.
    private func fullResync<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>,
        metadata: SyncMetadata,
        context: ModelContext
    ) async throws -> SyncResponseDTO<Change> {
        try adapter.purgeSynced(context)
        metadata.cursor = nil
        try context.save()
        await track(.fullResyncStarted(resource: adapter.resourceName))
        return try await adapter.call(
            SyncRequestDTO(since: nil, limit: limit, upserts: [], deletes: [])
        )
    }
}

// MARK: - Type erasure

/// A type-erased ``SyncResourceAdapter`` for use with ``SyncEngine/syncAll(_:)``.
///
/// Adapters are generic over four type parameters, so a heterogeneous list can't
/// name a single adapter type. Wrap each adapter in an `AnySyncResource` to sync
/// them together.
@MainActor
public struct AnySyncResource {
    /// Erases a concrete adapter.
    public init<Model, Upsert, Delete, Change>(
        _ adapter: SyncResourceAdapter<Model, Upsert, Delete, Change>
    ) {
        resourceName = adapter.resourceName
        run = { try await $0.drive(adapter) }
    }

    /// Stable identifier for the wrapped resource.
    public let resourceName: String

    let run: (SyncEngine) async throws -> Void
}
