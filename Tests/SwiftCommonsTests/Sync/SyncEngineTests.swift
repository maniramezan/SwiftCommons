import Foundation
import SwiftData
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@MainActor
@Suite("SyncEngine")
struct SyncEngineTests {

    /// Collects the engine's lifecycle events for assertions.
    @MainActor
    final class EventLog {
        private(set) var events: [SyncEvent] = []
        func record(_ event: SyncEvent) { events.append(event) }
    }

    // MARK: Push + ack

    @Test func pendingTombstoneIsPushedAndAppliedDeleteMarksSynced() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let item = SyncItem(key: "run", title: "Run", serverId: 1001, syncState: .pendingDelete)
        item.isTombstoned = true
        context.insert(item)
        try context.save()

        let requestBox = Box<SyncRequestDTO<ItemUpsert, ItemDelete>?>(nil)
        let adapter = SyncFixtures.adapter { request in
            requestBox.value = request
            return SyncFixtures.response(
                applied: [
                    SyncAppliedDTO(
                        key: "run", id: 1001, status: "deleted", updatedAt: 1_780_000_000,
                        reason: nil)
                ],
                cursor: "cursor-1"
            )
        }

        let engine = SyncEngine(modelContainer: container)
        try await engine.sync(adapter)

        let request = try #require(requestBox.value)
        #expect(request.upserts.isEmpty)
        #expect(request.deletes.count == 1)
        #expect(request.deletes[0].id == 1001)
        #expect(item.isTombstoned)
        #expect(item.syncState == .synced)

        let metadata = try #require(try context.fetch(FetchDescriptor<SyncMetadata>()).first)
        #expect(metadata.resourceName == "items")
        #expect(metadata.cursor == "cursor-1")
    }

    @Test func createdAckSetsServerIdAndNormalizesKey() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        // Stored key is mixed-case; the server acks with the normalized key.
        let item = SyncItem(key: "Run", title: "Run", syncState: .pendingCreate)
        context.insert(item)
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                applied: [
                    SyncAppliedDTO(
                        key: "run", id: 101, status: "created", updatedAt: 2, reason: nil)
                ],
                cursor: "c"
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        #expect(item.syncState == .synced)
        #expect(item.serverId == 101)
        #expect(item.updatedAt == Date(timeIntervalSince1970: 2))
    }

    @Test func blockedAndRejectedStatusesMarkRowsBlocked() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let blocked = SyncItem(key: "b", title: "B", syncState: .pendingCreate)
        let rejected = SyncItem(key: "r", title: "R", syncState: .pendingCreate)
        context.insert(blocked)
        context.insert(rejected)
        try context.save()

        let log = EventLog()
        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                mode: "full",
                applied: [
                    SyncAppliedDTO(
                        key: "b", id: nil, status: "blocked", updatedAt: nil, reason: "quota"),
                    SyncAppliedDTO(
                        key: "r", id: nil, status: "rejected", updatedAt: nil, reason: "invalid"),
                ]
            )
        }
        let engine = SyncEngine(
            modelContainer: container, events: { await log.record($0) })
        try await engine.sync(adapter)

        #expect(blocked.syncState == .blocked)
        #expect(rejected.syncState == .blocked)
        #expect(
            log.events.contains(.itemBlocked(resource: "items", status: "blocked", reason: "quota"))
        )
        #expect(
            log.events.contains(
                .itemBlocked(resource: "items", status: "rejected", reason: "invalid")))
    }

    @Test func updatedNoopAndUnknownStatusesApplyCorrectly() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let updated = SyncItem(key: "u", title: "U", syncState: .pendingUpdate)
        let noop = SyncItem(key: "n", title: "N", syncState: .pendingUpdate)
        let unknown = SyncItem(key: "x", title: "X", syncState: .pendingUpdate)
        for item in [updated, noop, unknown] { context.insert(item) }
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                applied: [
                    SyncAppliedDTO(
                        key: "u", id: nil, status: "updated", updatedAt: nil, reason: nil),
                    SyncAppliedDTO(key: "n", id: nil, status: "noop", updatedAt: nil, reason: nil),
                    SyncAppliedDTO(
                        key: "x", id: nil, status: "mystery", updatedAt: nil, reason: nil),
                ]
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        #expect(updated.syncState == .synced)
        #expect(noop.syncState == .synced)
        // An unrecognized status is left untouched so the row re-pushes next pass.
        #expect(unknown.syncState == .pendingUpdate)
    }

    @Test func ackGuardSkipsRowEditedMidFlight() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let item = SyncItem(key: "k", title: "K", syncState: .pendingUpdate)
        context.insert(item)
        try context.save()

        let itemBox = Box<SyncItem>(item)
        let adapter = SyncFixtures.adapter { _ in
            // Simulate a local edit landing while the request was in flight.
            itemBox.value.localUpdatedAt = Date(timeIntervalSince1970: 999)
            return SyncFixtures.response(
                applied: [
                    SyncAppliedDTO(key: "k", id: 7, status: "updated", updatedAt: 2, reason: nil)
                ]
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        // The mid-flight edit means the ack no longer matches; the row stays pending.
        #expect(item.syncState == .pendingUpdate)
        #expect(item.serverId == nil)
    }

    // MARK: Ingest

    @Test func serverChangeDoesNotClobberPendingLocalRow() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let item = SyncItem(key: "run", title: "Local", serverId: 5, syncState: .pendingUpdate)
        context.insert(item)
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                serverChanges: [
                    ItemChange(key: "run", title: "Server", serverId: 5, isDeleted: false)
                ],
                cursor: "cursor-1"
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        #expect(item.syncState == .pendingUpdate)
        #expect(item.title == "Local")
    }

    @Test func serverChangeUpsertsNewAndExistingSyncedRows() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let existing = SyncItem(key: "a", title: "Old", serverId: 1, syncState: .synced)
        context.insert(existing)
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                serverChanges: [
                    ItemChange(key: "a", title: "New", serverId: 1, isDeleted: false),
                    ItemChange(key: "b", title: "Fresh", serverId: 2, isDeleted: false),
                ],
                cursor: "c"
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        let items = try context.fetch(FetchDescriptor<SyncItem>())
        #expect(items.first { $0.key == "a" }?.title == "New")
        #expect(items.contains { $0.key == "b" && $0.title == "Fresh" })
    }

    @Test func fullSnapshotTombstonesMissingRowsButPreservesExistingTombstones() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let active = SyncItem(key: "a", title: "Old Active", serverId: 1, syncState: .synced)
        let tombstone = SyncItem(key: "t", title: "Deleted", serverId: 2, syncState: .synced)
        tombstone.isTombstoned = true
        context.insert(active)
        context.insert(tombstone)
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                mode: "full",
                serverChanges: [
                    ItemChange(key: "s", title: "Server", serverId: 3, isDeleted: false)
                ]
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        let items = try context.fetch(FetchDescriptor<SyncItem>())
        #expect(items.first { $0.key == "a" }?.isTombstoned == true)
        #expect(items.first { $0.key == "t" }?.isTombstoned == true)
        #expect(items.first { $0.key == "s" }?.isTombstoned == false)
    }

    @Test func fullSnapshotIgnoresDeletedServerChangesWhenBuildingActiveKeys() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let active = SyncItem(key: "keep", title: "Keep", serverId: 1, syncState: .synced)
        context.insert(active)
        try context.save()

        let adapter = SyncFixtures.adapter { _ in
            // A deleted change must not add "keep" to the active set, so the local
            // "keep" row (absent from the active snapshot) gets tombstoned.
            SyncFixtures.response(
                mode: "full",
                serverChanges: [
                    ItemChange(key: "keep", title: "Keep", serverId: 1, isDeleted: true)
                ]
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        #expect(active.isTombstoned)
    }

    @Test func deltaDrainsAllPagesWhenHasMore() async throws {
        let container = try SyncFixtures.makeContainer()
        let callCount = Box<Int>(0)
        let adapter = SyncFixtures.adapter { _ in
            let call = callCount.value
            callCount.value += 1
            if call == 0 {
                return SyncFixtures.response(
                    serverChanges: [
                        ItemChange(key: "alpha", title: "A", serverId: 10, isDeleted: false)
                    ],
                    cursor: "page-1",
                    hasMore: true
                )
            }
            return SyncFixtures.response(
                serverChanges: [
                    ItemChange(key: "beta", title: "B", serverId: 11, isDeleted: false)
                ],
                cursor: "page-2"
            )
        }
        try await SyncEngine(modelContainer: container).sync(adapter)

        let context = container.mainContext
        let items = try context.fetch(FetchDescriptor<SyncItem>())
        #expect(callCount.value == 2)
        #expect(items.contains { $0.key == "alpha" })
        #expect(items.contains { $0.key == "beta" })
        let metadata = try #require(try context.fetch(FetchDescriptor<SyncMetadata>()).first)
        #expect(metadata.cursor == "page-2")
    }

    // MARK: Full resync

    @Test func fullResyncPurgesSyncedRowsAndResetsCursor() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let stale = SyncItem(key: "stale", title: "Stale", serverId: 9, syncState: .synced)
        context.insert(stale)
        try context.save()

        let callCount = Box<Int>(0)
        let log = EventLog()
        let adapter = SyncFixtures.adapter { _ in
            let call = callCount.value
            callCount.value += 1
            return SyncFixtures.response(
                mode: call == 0 ? "delta" : "full",
                cursor: call == 0 ? nil : "fresh",
                fullResyncRequired: call == 0
            )
        }
        let engine = SyncEngine(modelContainer: container, events: { await log.record($0) })
        try await engine.sync(adapter)

        let remaining = try context.fetch(FetchDescriptor<SyncItem>())
        #expect(callCount.value == 2)
        #expect(remaining.allSatisfy { $0.key != "stale" })
        #expect(log.events.contains(.fullResyncStarted(resource: "items")))
        let metadata = try #require(try context.fetch(FetchDescriptor<SyncMetadata>()).first)
        #expect(metadata.cursor == "fresh")
    }

    // MARK: Events

    @Test func startedAndCompletedEventsAreEmitted() async throws {
        let container = try SyncFixtures.makeContainer()
        let log = EventLog()
        let adapter = SyncFixtures.adapter { _ in SyncFixtures.response(mode: "delta", cursor: "c")
        }
        let engine = SyncEngine(modelContainer: container, events: { await log.record($0) })
        try await engine.sync(adapter)

        #expect(log.events.first == .started(resource: "items"))
        let completed = log.events.contains {
            if case .completed(let resource, let mode, _, _, _) = $0 {
                return resource == "items" && mode == "delta"
            }
            return false
        }
        #expect(completed)
    }

    @Test func failedCallEmitsFailedEventAndRethrows() async throws {
        struct Boom: Error {}
        let container = try SyncFixtures.makeContainer()
        let log = EventLog()
        let adapter = SyncFixtures.adapter { _ in throw Boom() }
        let engine = SyncEngine(modelContainer: container, events: { await log.record($0) })

        await #expect(throws: Boom.self) { try await engine.sync(adapter) }

        let failed = log.events.contains {
            if case .failed(let resource, let errorType, _) = $0 {
                return resource == "items" && errorType == "Boom"
            }
            return false
        }
        #expect(failed)
    }

    @Test func serverInfoIsCopiedIntoMetadataAndReusedAcrossPasses() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let adapter = SyncFixtures.adapter { _ in
            SyncFixtures.response(cursor: "c", serverInfo: ["freeTierLimit": "10", "plan": "free"])
        }
        let engine = SyncEngine(modelContainer: container)

        try await engine.sync(adapter)
        // Second pass reuses the existing metadata row rather than inserting a new one.
        try await engine.sync(adapter)

        let metadataRows = try context.fetch(FetchDescriptor<SyncMetadata>())
        #expect(metadataRows.count == 1)
        let metadata = try #require(metadataRows.first)
        #expect(metadata.serverInfo["freeTierLimit"] == "10")
        #expect(metadata.serverInfo["plan"] == "free")
    }

    // MARK: syncAll

    @Test func syncAllRunsEveryResourceAndIsolatesFailures() async throws {
        struct Boom: Error {}
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let secondRan = Box<Bool>(false)

        let failing = AnySyncResource(
            SyncFixtures.adapter(resourceName: "first") { _ in throw Boom() })
        let succeeding = AnySyncResource(
            SyncFixtures.adapter(resourceName: "second") { _ in
                secondRan.value = true
                return SyncFixtures.response(cursor: "c")
            })

        let engine = SyncEngine(modelContainer: container)
        await #expect(throws: Boom.self) {
            try await engine.syncAll([failing, succeeding])
        }

        // The failure in the first resource must not stop the second.
        #expect(secondRan.value)
        let metadata = try context.fetch(FetchDescriptor<SyncMetadata>())
        #expect(metadata.contains { $0.resourceName == "second" && $0.cursor == "c" })
    }

    @Test func syncAllSucceedsForAllResources() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let resources = [
            AnySyncResource(
                SyncFixtures.adapter(resourceName: "one") { _ in SyncFixtures.response(cursor: "1")
                }
            ),
            AnySyncResource(
                SyncFixtures.adapter(resourceName: "two") { _ in SyncFixtures.response(cursor: "2")
                }
            ),
        ]
        #expect(resources.map(\.resourceName) == ["one", "two"])

        try await SyncEngine(modelContainer: container).syncAll(resources)

        let metadata = try context.fetch(FetchDescriptor<SyncMetadata>())
        #expect(metadata.count == 2)
    }

    // MARK: Serialization

    @Test func injectedLockSerializesConcurrentSyncs() async throws {
        let container = try SyncFixtures.makeContainer()
        let order = Box<[String]>([])
        let lock = AsyncLock()

        func adapter(_ tag: String) -> SyncResourceAdapter<
            SyncItem, ItemUpsert, ItemDelete, ItemChange
        > {
            SyncFixtures.adapter(resourceName: tag) { _ in
                order.value.append("enter-\(tag)")
                for _ in 0..<5 { await Task.yield() }
                order.value.append("exit-\(tag)")
                return SyncFixtures.response(cursor: tag)
            }
        }

        let engineA = SyncEngine(modelContainer: container, lock: lock)
        let engineB = SyncEngine(modelContainer: container, lock: lock)
        async let a: Void = engineA.sync(adapter("a"))
        async let b: Void = engineB.sync(adapter("b"))
        _ = try await (a, b)

        // With a shared lock, one pass fully finishes before the other starts.
        #expect(order.value == ["enter-a", "exit-a", "enter-b", "exit-b"])
    }

    @Test func changeWithoutKeyIsIgnoredDuringReconciliation() async throws {
        let container = try SyncFixtures.makeContainer()
        let context = container.mainContext
        let active = SyncItem(key: "keep", title: "Keep", serverId: 1, syncState: .synced)
        context.insert(active)
        try context.save()

        // A resource whose changeKey is always nil: no change can keep a row active,
        // so the full snapshot tombstones the pre-existing row.
        let base = SyncFixtures.adapter { _ in
            SyncFixtures.response(
                mode: "full",
                serverChanges: [
                    ItemChange(key: "keep", title: "Keep", serverId: 1, isDeleted: false)
                ]
            )
        }
        let adapter = SyncResourceAdapter(
            resourceName: base.resourceName,
            fetchPending: base.fetchPending,
            businessKey: base.businessKey,
            makeUpserts: base.makeUpserts,
            makeDeletes: base.makeDeletes,
            call: base.call,
            findExisting: base.findExisting,
            changeKey: { _ in nil },
            isChangeDeleted: base.isChangeDeleted,
            upsertFromChange: base.upsertFromChange,
            fetchActive: base.fetchActive,
            purgeSynced: base.purgeSynced
        )
        try await SyncEngine(modelContainer: container).sync(adapter)

        #expect(active.isTombstoned)
    }
}
