#if SwiftData
import Foundation
import OSLog
import SwiftData

/// A ``SyncStore`` that syncs a SwiftData container's `mainContext` on the main actor.
///
/// Each transaction runs on the main actor against `mainContext` and ends with `save()`, so
/// synced rows show up in SwiftUI views bound to that context as each page commits. Checkpoints
/// live in ``SyncMetadata`` rows, which the container's schema must include.
///
/// A throwing transaction is not rolled back: `mainContext` is shared with the app, and a
/// rollback would also discard the app's own unsaved edits. Use
/// ``SwiftDataBackgroundSyncStore`` to sync on a private context instead.
public struct SwiftDataSyncStore: SyncStore {
    /// Creates a store over a container's `mainContext`.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// The container whose `mainContext` holds the synced rows and ``SyncMetadata``.
    public let modelContainer: ModelContainer

    /// Runs `body` on the main actor against `mainContext`, then saves.
    public func transaction<T: Sendable>(
        _ body: @Sendable (ModelContext) throws -> T
    ) async throws -> T {
        try await MainActor.run {
            let context = modelContainer.mainContext
            let result = try body(context)
            try context.save()
            return result
        }
    }

    /// Reads the resource's ``SyncMetadata`` row as a checkpoint.
    public func checkpoint(
        for resourceName: String, in context: ModelContext
    ) throws -> SyncCheckpoint? {
        try SyncMetadata.checkpoint(for: resourceName, in: context)
    }

    /// Writes the checkpoint into the resource's ``SyncMetadata`` row, inserting it if needed.
    public func saveCheckpoint(
        _ checkpoint: SyncCheckpoint, for resourceName: String, in context: ModelContext
    ) throws {
        try SyncMetadata.save(checkpoint, for: resourceName, in: context)
    }
}

/// A ``SyncStore`` that syncs a SwiftData container on its own background context.
///
/// Transactions run on this actor's private `ModelContext`, off the main actor, and a
/// throwing transaction is rolled back so a failed page leaves no partial writes behind.
/// Changes reach the main context through SwiftData's normal cross-context merge. Checkpoints
/// live in ``SyncMetadata`` rows, which the container's schema must include.
@ModelActor
public actor SwiftDataBackgroundSyncStore: SyncStore {

    /// Runs `body` on this actor's context, then saves; rolls back if `body` or the save throws.
    public func transaction<T: Sendable>(
        _ body: @Sendable (ModelContext) throws -> T
    ) async throws -> T {
        do {
            let result = try body(modelContext)
            try modelContext.save()
            return result
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Reads the resource's ``SyncMetadata`` row as a checkpoint.
    public nonisolated func checkpoint(
        for resourceName: String, in context: ModelContext
    ) throws -> SyncCheckpoint? {
        try SyncMetadata.checkpoint(for: resourceName, in: context)
    }

    /// Writes the checkpoint into the resource's ``SyncMetadata`` row, inserting it if needed.
    public nonisolated func saveCheckpoint(
        _ checkpoint: SyncCheckpoint, for resourceName: String, in context: ModelContext
    ) throws {
        try SyncMetadata.save(checkpoint, for: resourceName, in: context)
    }
}

extension SyncMetadata {

    fileprivate static func row(
        for resourceName: String, in context: ModelContext
    ) throws -> SyncMetadata? {
        var descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.resourceName == resourceName }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    fileprivate static func checkpoint(
        for resourceName: String, in context: ModelContext
    ) throws -> SyncCheckpoint? {
        try row(for: resourceName, in: context).map {
            SyncCheckpoint(
                cursor: $0.cursor,
                syncVersion: $0.syncVersion,
                lastSyncedAt: $0.lastSyncedAt,
                serverInfo: $0.serverInfo
            )
        }
    }

    fileprivate static func save(
        _ checkpoint: SyncCheckpoint, for resourceName: String, in context: ModelContext
    ) throws {
        guard let existing = try row(for: resourceName, in: context) else {
            context.insert(
                SyncMetadata(
                    resourceName: resourceName,
                    cursor: checkpoint.cursor,
                    syncVersion: checkpoint.syncVersion,
                    lastSyncedAt: checkpoint.lastSyncedAt,
                    serverInfo: checkpoint.serverInfo
                )
            )
            return
        }
        existing.cursor = checkpoint.cursor
        existing.syncVersion = checkpoint.syncVersion
        existing.lastSyncedAt = checkpoint.lastSyncedAt
        existing.serverInfo = checkpoint.serverInfo
    }
}

// MARK: - SwiftData conveniences

/// A ``SyncEngine`` over a container's `mainContext`.
public typealias SwiftDataSyncEngine = SyncEngine<SwiftDataSyncStore>

/// A ``SyncResourceAdapter`` whose closures read and write through a SwiftData `ModelContext`,
/// usable with both ``SwiftDataSyncStore`` and ``SwiftDataBackgroundSyncStore``.
public typealias SwiftDataSyncAdapter<
    Model: SyncableModel,
    Upsert: Encodable & Sendable,
    Delete: Encodable & Sendable,
    Change: Decodable & Sendable
> = SyncResourceAdapter<Model, Upsert, Delete, Change, ModelContext>

extension SyncEngine where Store == SwiftDataSyncStore {

    /// Creates a sync engine over a container's `mainContext`.
    /// - Parameters:
    ///   - modelContainer: The SwiftData container whose `mainContext` holds the
    ///     synced rows and ``SyncMetadata``.
    ///   - limit: Maximum number of server changes requested per page.
    ///   - lock: Serializes passes. Share one instance across engines that must
    ///     not run concurrently.
    ///   - events: Handler for ``SyncEvent`` lifecycle events.
    ///   - logger: Logger for failures and pass tracing.
    public convenience init(
        modelContainer: ModelContainer,
        limit: Int = 100,
        lock: AsyncLock = AsyncLock(),
        events: @escaping @Sendable (SyncEvent) async -> Void = { _ in },
        logger: Logger = .swiftCommonsLogger(category: "SyncEngine")
    ) {
        self.init(
            store: SwiftDataSyncStore(modelContainer: modelContainer),
            limit: limit,
            lock: lock,
            events: events,
            logger: logger
        )
    }
}

extension AnySyncResource where Store == SwiftDataSyncStore {

    /// Erases a SwiftData adapter for a ``SwiftDataSyncEngine``.
    public init<Model, Upsert, Delete, Change>(
        _ adapter: SwiftDataSyncAdapter<Model, Upsert, Delete, Change>
    ) {
        resourceName = adapter.resourceName
        run = { try await $0.drive(adapter) }
    }
}

extension SyncResourceAdapter where Context == ModelContext {

    /// Creates a SwiftData adapter from its resource-specific closures.
    ///
    /// SwiftData models are live objects, so the engine's acknowledgement and tombstone
    /// writes land on the managed rows directly and no `persist` closure is needed. The
    /// optional `findExistingBatch` defaults to `nil`.
    public init(
        resourceName: String,
        fetchPending: @escaping @Sendable (ModelContext) throws -> [Model],
        businessKey: @escaping @Sendable (Model) -> String,
        makeUpserts: @escaping @Sendable ([Model]) -> [Upsert],
        makeDeletes: @escaping @Sendable ([Model]) -> [Delete],
        call:
            @escaping @Sendable (SyncRequestDTO<Upsert, Delete>) async throws ->
            SyncResponseDTO<Change>,
        findExisting: @escaping @Sendable (Change, ModelContext) throws -> Model?,
        changeKey: @escaping @Sendable (Change) -> String?,
        isChangeDeleted: @escaping @Sendable (Change) -> Bool,
        upsertFromChange: @escaping @Sendable (Change, Model?, ModelContext) throws -> Void,
        fetchActive: @escaping @Sendable (ModelContext) throws -> [Model],
        purgeSynced: @escaping @Sendable (ModelContext) throws -> Void,
        findExistingBatch: (@Sendable ([Change], ModelContext) throws -> [String: Model])? =
            nil
    ) {
        self.init(
            resourceName: resourceName,
            fetchPending: fetchPending,
            businessKey: businessKey,
            makeUpserts: makeUpserts,
            makeDeletes: makeDeletes,
            call: call,
            findExisting: findExisting,
            changeKey: changeKey,
            isChangeDeleted: isChangeDeleted,
            upsertFromChange: upsertFromChange,
            fetchActive: fetchActive,
            purgeSynced: purgeSynced,
            persist: { _, _ in },
            findExistingBatch: findExistingBatch
        )
    }
}
#endif
