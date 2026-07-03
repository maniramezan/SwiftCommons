import Foundation
import SwiftData

@testable import SwiftCommons

// A minimal syncable resource used to exercise the generic engine.

@Model
final class SyncItem: SyncableModel {
    init(
        key: String,
        title: String,
        serverId: Int? = nil,
        syncState: SyncState = .synced,
        isTombstoned: Bool = false,
        localUpdatedAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.key = key
        self.title = title
        self.serverId = serverId
        self.syncState = syncState
        self.isTombstoned = isTombstoned
        self.localUpdatedAt = localUpdatedAt
        updatedAt = Date(timeIntervalSince1970: 0)
    }

    var key: String
    var title: String
    var serverId: Int?
    var updatedAt: Date
    var isTombstoned: Bool
    var syncState: SyncState
    var localUpdatedAt: Date
}

struct ItemUpsert: Encodable, Sendable {
    let key: String
    let title: String
}

struct ItemDelete: Encodable, Sendable {
    let id: Int?
    let key: String
}

struct ItemChange: Decodable, Sendable {
    let key: String
    let title: String
    let serverId: Int
    let isDeleted: Bool
}

typealias ItemResponse = SyncResponseDTO<ItemChange>

/// A mutable capture box for recording values inside adapter closures.
@MainActor
final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

enum SyncFixtures {
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: SyncItem.self, SyncMetadata.self, configurations: config)
    }

    /// Builds an adapter whose transport is the supplied `call` closure.
    ///
    /// ``SyncResourceAdapter/businessKey`` lowercases the item key, so the tests can
    /// verify server-side key normalization the same way a real backend would.
    @MainActor
    static func adapter(
        resourceName: String = "items",
        call: @escaping (SyncRequestDTO<ItemUpsert, ItemDelete>) async throws -> ItemResponse
    ) -> SyncResourceAdapter<SyncItem, ItemUpsert, ItemDelete, ItemChange> {
        SyncResourceAdapter(
            resourceName: resourceName,
            fetchPending: { context in
                try context.fetch(FetchDescriptor<SyncItem>()).filter { $0.syncState != .synced }
            },
            businessKey: { $0.key.lowercased() },
            makeUpserts: { models in
                models.filter { !$0.isTombstoned }.map { ItemUpsert(key: $0.key, title: $0.title) }
            },
            makeDeletes: { models in
                models.filter { $0.isTombstoned }.map { ItemDelete(id: $0.serverId, key: $0.key) }
            },
            call: call,
            findExisting: { change, context in
                try context.fetch(FetchDescriptor<SyncItem>())
                    .first { $0.key.lowercased() == change.key.lowercased() }
            },
            changeKey: { $0.key.lowercased() },
            isChangeDeleted: { $0.isDeleted },
            upsertFromChange: { change, existing, context in
                if let existing {
                    existing.title = change.title
                    existing.serverId = change.serverId
                    existing.isTombstoned = change.isDeleted
                    existing.syncState = .synced
                } else {
                    let item = SyncItem(
                        key: change.key,
                        title: change.title,
                        serverId: change.serverId,
                        syncState: .synced,
                        isTombstoned: change.isDeleted
                    )
                    context.insert(item)
                }
            },
            fetchActive: { context in
                try context.fetch(FetchDescriptor<SyncItem>()).filter { !$0.isTombstoned }
            },
            purgeSynced: { context in
                for item in try context.fetch(FetchDescriptor<SyncItem>())
                where item.syncState == .synced {
                    context.delete(item)
                }
            }
        )
    }

    static func response(
        mode: String = "delta",
        applied: [SyncAppliedDTO] = [],
        serverChanges: [ItemChange] = [],
        cursor: String? = nil,
        hasMore: Bool = false,
        fullResyncRequired: Bool = false,
        serverInfo: [String: String]? = nil
    ) -> ItemResponse {
        ItemResponse(
            syncVersion: 1,
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
