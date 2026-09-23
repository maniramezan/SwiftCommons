import Foundation
import SwiftData
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

@Model
private final class SyncFixtureItem {
    init(name: String) {
        self.name = name
    }

    var name: String
}

@MainActor
@Suite("Sync fixtures")
struct SyncFixturesTests {
    @Test
    func syncContainerIncludesSyncMetadata() throws {
        let container = try makeInMemorySyncContainer(for: SyncFixtureItem.self)
        let context = container.mainContext
        context.insert(SyncMetadata(resourceName: "items"))
        context.insert(SyncFixtureItem(name: "widget"))
        try context.save()

        #expect(try context.fetch(FetchDescriptor<SyncMetadata>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<SyncFixtureItem>()).count == 1)
    }

    @Test
    func responseFixtureDefaultsToAnEmptyDeltaPage() {
        let response = SyncResponseDTO<String>.fixture()
        #expect(response.syncVersion == 1)
        #expect(response.mode == "delta")
        #expect(response.applied.isEmpty)
        #expect(response.serverChanges.isEmpty)
        #expect(response.cursor == nil)
        #expect(!response.hasMore)
        #expect(!response.fullResyncRequired)
        #expect(response.serverInfo == nil)
    }

    @Test
    func responseFixturePassesThroughOverrides() {
        let response = SyncResponseDTO<String>.fixture(
            mode: "full",
            applied: [.fixture(key: "run", id: 7, status: "created")],
            serverChanges: ["change"],
            cursor: "cursor-1",
            hasMore: true,
            fullResyncRequired: true,
            serverInfo: ["quota": "10"]
        )
        #expect(response.mode == "full")
        #expect(
            response.applied
                == [
                    SyncAppliedDTO(
                        key: "run", id: 7, status: "created", updatedAt: nil, reason: nil)
                ]
        )
        #expect(response.serverChanges == ["change"])
        #expect(response.cursor == "cursor-1")
        #expect(response.hasMore)
        #expect(response.fullResyncRequired)
        #expect(response.serverInfo == ["quota": "10"])
    }

    @Test
    func appliedFixtureDefaultsToUpdated() {
        let applied = SyncAppliedDTO.fixture(key: "run")
        #expect(
            applied
                == SyncAppliedDTO(
                    key: "run", id: nil, status: "updated", updatedAt: nil, reason: nil))
    }
}
