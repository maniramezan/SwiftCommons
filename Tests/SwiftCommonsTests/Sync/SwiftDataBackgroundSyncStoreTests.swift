#if SwiftData
import Foundation
import SwiftData
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@MainActor
@Suite("SwiftDataBackgroundSyncStore")
struct SwiftDataBackgroundSyncStoreTests {

    @Test func passPersistsRowsAndCursorVisibleFromAFreshContext() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        context.insert(SyncItem(key: "run", title: "Run", syncState: .pendingCreate))
        try context.save()
        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                applied: [.fixture(key: "run", id: 101, status: "created")],
                serverChanges: [
                    ItemChange(key: "alpha", title: "Alpha", serverId: 1, isDeleted: false)
                ],
                cursor: "cursor-1"
            )
        }
        let engine = SyncEngine(store: SwiftDataBackgroundSyncStore(modelContainer: container))

        try await engine.sync(adapter)

        let fresh = ModelContext(container)
        let items = try fresh.fetch(FetchDescriptor<SyncItem>(sortBy: [SortDescriptor(\.key)]))
        #expect(items.map(\.key) == ["alpha", "run"])
        #expect(items.allSatisfy { $0.syncState == .synced })
        #expect(items.last?.serverId == 101)
        let metadata = try #require(try fresh.fetch(FetchDescriptor<SyncMetadata>()).first)
        #expect(metadata.cursor == "cursor-1")
    }

    @Test func failedPageRollsBackTheBackgroundContext() async throws {
        struct IngestError: Error {}
        let container = try SyncFixtures.makeContainer()
        let base = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                serverChanges: [
                    ItemChange(key: "alpha", title: "Alpha", serverId: 1, isDeleted: false),
                    ItemChange(key: "beta", title: "Boom", serverId: 2, isDeleted: false),
                ],
                cursor: "cursor-1"
            )
        }
        let adapter = SwiftDataSyncAdapter(
            resourceName: base.resourceName,
            fetchPending: base.fetchPending,
            businessKey: base.businessKey,
            makeUpserts: base.makeUpserts,
            makeDeletes: base.makeDeletes,
            call: base.call,
            findExisting: base.findExisting,
            changeKey: base.changeKey,
            isChangeDeleted: base.isChangeDeleted,
            upsertFromChange: { change, existing, context in
                if change.title == "Boom" { throw IngestError() }
                try base.upsertFromChange(change, existing, context)
            },
            fetchActive: base.fetchActive,
            purgeSynced: base.purgeSynced
        )
        let store = SwiftDataBackgroundSyncStore(modelContainer: container)

        await #expect(throws: IngestError.self) {
            try await SyncEngine(store: store).sync(adapter)
        }

        let fresh = ModelContext(container)
        #expect(try fresh.fetch(FetchDescriptor<SyncItem>()).isEmpty)
        #expect(try fresh.fetch(FetchDescriptor<SyncMetadata>()).isEmpty)
        // The rolled-back context is reusable: the next transaction starts clean.
        let staged = try await store.transaction { try $0.fetch(FetchDescriptor<SyncItem>()).count }
        #expect(staged == 0)
    }

    @Test func syncAllRunsResourcesOnTheBackgroundStore() async throws {
        let container = try SyncFixtures.makeContainer()
        let engine = SyncEngine(store: SwiftDataBackgroundSyncStore(modelContainer: container))
        let resources = ["one", "two"].map { name in
            AnySyncResource<SwiftDataBackgroundSyncStore>(
                SyncFixtures.adapter(resourceName: name) { _ in
                    SyncFixtures.response(cursor: name)
                }
            )
        }

        try await engine.syncAll(resources)

        let metadata = try ModelContext(container).fetch(FetchDescriptor<SyncMetadata>())
        #expect(Set(metadata.compactMap(\.cursor)) == ["one", "two"])
    }
}
#endif
