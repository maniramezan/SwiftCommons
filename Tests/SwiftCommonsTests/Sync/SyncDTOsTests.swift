import Foundation
import Testing

@testable import SwiftCommons

@Suite("Sync DTOs")
struct SyncDTOsTests {

    @Test func responseDecodesEngineFieldsAndNestedServerInfo() throws {
        let json = """
            {
              "syncVersion": 2,
              "mode": "full",
              "applied": [
                { "key": "a", "id": 1, "status": "created", "updatedAt": 12.5, "reason": null }
              ],
              "serverChanges": [ { "key": "a", "title": "A", "serverId": 1, "isDeleted": false } ],
              "cursor": "c1",
              "hasMore": true,
              "fullResyncRequired": false,
              "serverInfo": { "plan": "free" }
            }
            """
        let response = try JSONDecoder().decode(ItemResponse.self, from: Data(json.utf8))

        #expect(response.syncVersion == 2)
        #expect(response.mode == "full")
        #expect(response.applied.first?.status == "created")
        #expect(response.applied.first?.updatedAt == 12.5)
        #expect(response.serverChanges.first?.title == "A")
        #expect(response.cursor == "c1")
        #expect(response.hasMore)
        #expect(!response.fullResyncRequired)
        #expect(response.serverInfo?["plan"] == "free")
    }

    @Test func responseDecodesWithoutServerInfoOrCursor() throws {
        let json = """
            {
              "syncVersion": 1,
              "mode": "delta",
              "applied": [],
              "serverChanges": [],
              "cursor": null,
              "hasMore": false,
              "fullResyncRequired": true
            }
            """
        let response = try JSONDecoder().decode(ItemResponse.self, from: Data(json.utf8))

        #expect(response.cursor == nil)
        #expect(response.serverInfo == nil)
        #expect(response.fullResyncRequired)
    }

    @Test(
        arguments: [
            ("created", SyncAppliedDTO.Status.created),
            ("updated", .updated),
            ("deleted", .deleted),
            ("noop", .noop),
            ("blocked", .blocked),
            ("rejected", .rejected),
            ("queued", .unknown("queued")),
        ]
    )
    func appliedStatusMapsWireStringsAndRoundTripsThem(
        wire: String, expected: SyncAppliedDTO.Status
    ) {
        let applied = SyncAppliedDTO(
            key: "a", id: nil, status: wire, updatedAt: nil, reason: nil)

        #expect(applied.statusKind == expected)
        #expect(SyncAppliedDTO.Status(rawValue: wire) == expected)
        #expect(expected.rawValue == wire)
    }

    @Test(
        arguments: [
            ("full", SyncResponseMode.full),
            ("delta", .delta),
            ("snapshot", .unknown("snapshot")),
        ]
    )
    func responseModeMapsWireStringsAndRoundTripsThem(wire: String, expected: SyncResponseMode) {
        let response = ItemResponse(
            syncVersion: 1, mode: wire, applied: [], serverChanges: [], cursor: nil,
            hasMore: false, fullResyncRequired: false)

        #expect(response.modeKind == expected)
        #expect(expected.rawValue == wire)
    }

    @Test func requestEncodesAllFields() throws {
        let request = SyncRequestDTO(
            since: "cursor",
            limit: 50,
            upserts: [ItemUpsert(key: "a", title: "A")],
            deletes: [ItemDelete(id: 9, key: "b")]
        )
        let data = try JSONEncoder().encode(request)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["since"] as? String == "cursor")
        #expect(object["limit"] as? Int == 50)
        #expect((object["upserts"] as? [[String: Any]])?.count == 1)
        #expect((object["deletes"] as? [[String: Any]])?.count == 1)
    }

    @Test func appliedDTOIsEquatable() {
        let lhs = SyncAppliedDTO(key: "k", id: 1, status: "created", updatedAt: 1, reason: nil)
        let rhs = SyncAppliedDTO(key: "k", id: 1, status: "created", updatedAt: 1, reason: nil)
        #expect(lhs == rhs)
    }
}
