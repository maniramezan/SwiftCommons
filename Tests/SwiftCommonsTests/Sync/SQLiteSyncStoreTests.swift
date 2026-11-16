import Foundation
import SQLite3
import Testing

@testable import SwiftCommons
@testable import SwiftCommonsTestSupport

// A test-only SQL store: value-type rows, a connection that only exists inside a
// BEGIN/COMMIT transaction, and a checkpoint table. It exercises the engine without SwiftData,
// so it runs in every trait configuration.

struct SQLiteError: Error, Equatable {
    let message: String
}

/// A row in the `items` table.
struct SQLItem: SyncableModel, Equatable {
    var key: String
    var title: String
    var serverId: Int? = nil
    var updatedAt = Date(timeIntervalSince1970: 0)
    var isTombstoned = false
    var syncState: SyncState = .synced
    var localUpdatedAt = Date(timeIntervalSince1970: 0)
}

/// The write handle a transaction hands to adapter closures.
struct SQLiteConnection {
    let handle: OpaquePointer

    func execute(_ sql: String, _ bindings: [Binding] = []) throws {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw lastError() }
    }

    func query<Row>(
        _ sql: String, _ bindings: [Binding] = [], row: (OpaquePointer) -> Row
    ) throws -> [Row] {
        let statement = try prepare(sql, bindings)
        defer { sqlite3_finalize(statement) }
        var rows: [Row] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: rows.append(row(statement))
            case SQLITE_DONE: return rows
            default: throw lastError()
            }
        }
    }

    enum Binding {
        case text(String?)
        case integer(Int?)
        case real(Double)
    }

    private func prepare(_ sql: String, _ bindings: [Binding]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement
        else { throw lastError() }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            switch binding {
            case .text(let value?): sqlite3_bind_text(statement, index, value, -1, transient)
            case .integer(let value?): sqlite3_bind_int64(statement, index, Int64(value))
            case .real(let value): sqlite3_bind_double(statement, index, value)
            case .text(nil), .integer(nil): sqlite3_bind_null(statement, index)
            }
        }
        return statement
    }

    private func lastError() -> SQLiteError {
        SQLiteError(message: String(cString: sqlite3_errmsg(handle)))
    }
}

extension SQLiteConnection {

    func items(where clause: String = "1") throws -> [SQLItem] {
        try query(
            """
            SELECT key, title, server_id, updated_at, is_tombstoned, sync_state, local_updated_at
            FROM items WHERE \(clause) ORDER BY key
            """
        ) { statement in
            SQLItem(
                key: Self.text(statement, 0) ?? "",
                title: Self.text(statement, 1) ?? "",
                serverId: sqlite3_column_type(statement, 2) == SQLITE_NULL
                    ? nil : Int(sqlite3_column_int64(statement, 2)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                isTombstoned: sqlite3_column_int64(statement, 4) != 0,
                syncState: SyncState(rawValue: Self.text(statement, 5) ?? "") ?? .synced,
                localUpdatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
            )
        }
    }

    func item(key: String) throws -> SQLItem? {
        try items(where: "lower(key) = '\(key.lowercased())'").first
    }

    func save(_ item: SQLItem) throws {
        try execute(
            """
            INSERT OR REPLACE INTO items
            (key, title, server_id, updated_at, is_tombstoned, sync_state, local_updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                .text(item.key), .text(item.title), .integer(item.serverId),
                .real(item.updatedAt.timeIntervalSince1970), .integer(item.isTombstoned ? 1 : 0),
                .text(item.syncState.rawValue), .real(item.localUpdatedAt.timeIntervalSince1970),
            ]
        )
    }

    private static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }
}

/// Owns the database handle and closes it when the store goes away.
final class SQLiteDatabase {
    init(handle: OpaquePointer) {
        self.handle = handle
    }

    deinit {
        sqlite3_close(handle)
    }

    let handle: OpaquePointer
}

/// An in-memory SQLite ``SyncStore`` with explicit BEGIN/COMMIT/ROLLBACK.
actor SQLiteSyncStore: SyncStore {

    init() throws {
        var opened: OpaquePointer?
        guard sqlite3_open(":memory:", &opened) == SQLITE_OK, let opened else {
            throw SQLiteError(message: "open failed")
        }
        let connection = SQLiteConnection(handle: opened)
        try connection.execute(
            """
            CREATE TABLE items (
                key TEXT PRIMARY KEY, title TEXT NOT NULL, server_id INTEGER,
                updated_at REAL NOT NULL, is_tombstoned INTEGER NOT NULL,
                sync_state TEXT NOT NULL, local_updated_at REAL NOT NULL)
            """
        )
        try connection.execute(
            """
            CREATE TABLE sync_checkpoints (
                resource TEXT PRIMARY KEY, cursor TEXT, sync_version INTEGER NOT NULL,
                last_synced_at REAL, server_info TEXT NOT NULL)
            """
        )
        database = SQLiteDatabase(handle: opened)
    }

    func transaction<T: Sendable>(
        _ body: @Sendable (SQLiteConnection) throws -> T
    ) async throws -> T {
        let connection = SQLiteConnection(handle: database.handle)
        try connection.execute("BEGIN IMMEDIATE")
        do {
            let result = try body(connection)
            try connection.execute("COMMIT")
            return result
        } catch {
            try? connection.execute("ROLLBACK")
            throw error
        }
    }

    nonisolated func checkpoint(
        for resourceName: String, in context: SQLiteConnection
    ) throws -> SyncCheckpoint? {
        try context.query(
            """
            SELECT cursor, sync_version, last_synced_at, server_info
            FROM sync_checkpoints WHERE resource = ?
            """,
            [.text(resourceName)]
        ) { statement in
            let serverInfo = sqlite3_column_text(statement, 3)
                .flatMap { String(cString: $0).data(using: .utf8) }
                .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
            return SyncCheckpoint(
                cursor: sqlite3_column_text(statement, 0).map { String(cString: $0) },
                syncVersion: Int(sqlite3_column_int64(statement, 1)),
                lastSyncedAt: sqlite3_column_type(statement, 2) == SQLITE_NULL
                    ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                serverInfo: serverInfo ?? [:]
            )
        }.first
    }

    nonisolated func saveCheckpoint(
        _ checkpoint: SyncCheckpoint, for resourceName: String, in context: SQLiteConnection
    ) throws {
        let serverInfo = String(
            decoding: try JSONEncoder().encode(checkpoint.serverInfo), as: UTF8.self)
        try context.execute(
            """
            INSERT OR REPLACE INTO sync_checkpoints
            (resource, cursor, sync_version, last_synced_at, server_info)
            VALUES (?, ?, ?, ?, ?)
            """,
            [
                .text(resourceName), .text(checkpoint.cursor), .integer(checkpoint.syncVersion),
                checkpoint.lastSyncedAt.map { .real($0.timeIntervalSince1970) } ?? .text(nil),
                .text(serverInfo),
            ]
        )
    }

    private let database: SQLiteDatabase
}

typealias SQLItemAdapter = SyncResourceAdapter<
    SQLItem, ItemUpsert, ItemDelete, ItemChange, SQLiteConnection
>

extension SyncFixtures {

    /// Builds a SQL adapter whose transport is the supplied `call` closure. Ingesting a change
    /// titled `failingTitle` throws, to exercise page rollback.
    static func sqlAdapter(
        failingTitle: String? = nil,
        call:
            @escaping @MainActor (SyncRequestDTO<ItemUpsert, ItemDelete>) async throws ->
            ItemResponse
    ) -> SQLItemAdapter {
        SQLItemAdapter(
            resourceName: "items",
            fetchPending: { try $0.items(where: "sync_state != 'synced'") },
            businessKey: { $0.key.lowercased() },
            makeUpserts: { rows in
                rows.filter { !$0.isTombstoned }.map { ItemUpsert(key: $0.key, title: $0.title) }
            },
            makeDeletes: { rows in
                rows.filter(\.isTombstoned).map { ItemDelete(id: $0.serverId, key: $0.key) }
            },
            call: { request in try await call(request) },
            findExisting: { change, connection in try connection.item(key: change.key) },
            changeKey: { $0.key.lowercased() },
            isChangeDeleted: { $0.isDeleted },
            upsertFromChange: { change, existing, connection in
                if change.title == failingTitle {
                    throw SQLiteError(message: "rejected \(change.key)")
                }
                var row = existing ?? SQLItem(key: change.key, title: change.title)
                row.title = change.title
                row.serverId = change.serverId
                row.isTombstoned = change.isDeleted
                row.syncState = .synced
                try connection.save(row)
            },
            fetchActive: { try $0.items(where: "is_tombstoned = 0") },
            purgeSynced: { try $0.execute("DELETE FROM items WHERE sync_state = 'synced'") },
            persist: { row, connection in try connection.save(row) }
        )
    }
}

@MainActor
@Suite("SyncEngine over a SQL store")
struct SQLiteSyncStoreTests {

    private func seed(_ store: SQLiteSyncStore, _ items: SQLItem...) async throws {
        try await store.transaction { connection in
            for item in items { try connection.save(item) }
        }
    }

    private func rows(_ store: SQLiteSyncStore) async throws -> [SQLItem] {
        try await store.transaction { try $0.items() }
    }

    private func checkpoint(_ store: SQLiteSyncStore) async throws -> SyncCheckpoint? {
        try await store.transaction { try store.checkpoint(for: "items", in: $0) }
    }

    @Test func pushedRowIsAcknowledgedAndCursorCommitted() async throws {
        let store = try SQLiteSyncStore()
        try await seed(store, SQLItem(key: "Run", title: "Run", syncState: .pendingCreate))
        let requests = Box<[SyncRequestDTO<ItemUpsert, ItemDelete>]>([])
        let adapter = SyncFixtures.sqlAdapter { request in
            requests.value.append(request)
            return SyncFixtures.response(
                applied: [.fixture(key: "run", id: 101, status: "created", updatedAt: 2)],
                cursor: "cursor-1",
                serverInfo: ["plan": "free"]
            )
        }

        try await SyncEngine(store: store).sync(adapter)

        #expect(requests.value.map(\.upserts.count) == [1])
        let row = try #require(try await rows(store).first)
        #expect(row.syncState == .synced)
        #expect(row.serverId == 101)
        #expect(row.updatedAt == Date(timeIntervalSince1970: 2))
        let checkpoint = try #require(try await checkpoint(store))
        #expect(checkpoint.cursor == "cursor-1")
        #expect(checkpoint.serverInfo == ["plan": "free"])
    }

    @Test func rowEditedMidFlightStaysPending() async throws {
        let store = try SQLiteSyncStore()
        try await seed(store, SQLItem(key: "k", title: "K", syncState: .pendingUpdate))
        let adapter = SyncFixtures.sqlAdapter { _ in
            // A local edit lands while the request is in flight.
            try await store.transaction { connection in
                var row = try #require(try connection.item(key: "k"))
                row.localUpdatedAt = Date(timeIntervalSince1970: 999)
                try connection.save(row)
            }
            return SyncFixtures.response(
                applied: [.fixture(key: "k", id: 7, status: "updated", updatedAt: 2)])
        }

        try await SyncEngine(store: store).sync(adapter)

        let row = try #require(try await rows(store).first)
        #expect(row.syncState == .pendingUpdate)
        #expect(row.serverId == nil)
    }

    @Test func serverChangeDoesNotClobberPendingRow() async throws {
        let store = try SQLiteSyncStore()
        try await seed(
            store, SQLItem(key: "run", title: "Local", serverId: 5, syncState: .pendingUpdate))
        let adapter = SyncFixtures.sqlAdapter { _ in
            SyncFixtures.response(
                serverChanges: [
                    ItemChange(key: "run", title: "Server", serverId: 5, isDeleted: false)
                ],
                cursor: "cursor-1"
            )
        }

        try await SyncEngine(store: store).sync(adapter)

        let row = try #require(try await rows(store).first)
        #expect(row.title == "Local")
        #expect(row.syncState == .pendingUpdate)
    }

    @Test func fullSnapshotTombstonesAbsentRowsThroughPersist() async throws {
        let store = try SQLiteSyncStore()
        try await seed(
            store,
            SQLItem(key: "active", title: "Active", serverId: 1),
            SQLItem(key: "gone", title: "Gone", serverId: 2, isTombstoned: true)
        )
        let adapter = SyncFixtures.sqlAdapter { request in
            if request.since == nil {
                return SyncFixtures.response(
                    mode: "full",
                    serverChanges: [
                        ItemChange(key: "fresh", title: "Fresh", serverId: 3, isDeleted: false)
                    ],
                    cursor: "page-1",
                    hasMore: true
                )
            }
            return SyncFixtures.response(mode: "full", cursor: "page-2")
        }

        try await SyncEngine(store: store).sync(adapter)

        let byKey = Dictionary(uniqueKeysWithValues: try await rows(store).map { ($0.key, $0) })
        #expect(byKey["active"]?.isTombstoned == true)
        #expect(byKey["gone"]?.isTombstoned == true)
        #expect(byKey["fresh"]?.isTombstoned == false)
        #expect(try await checkpoint(store)?.cursor == "page-2")
    }

    @Test func fullResyncPurgesSyncedRowsAndKeepsPushAcks() async throws {
        let store = try SQLiteSyncStore()
        try await seed(
            store,
            SQLItem(key: "stale", title: "Stale", serverId: 9),
            SQLItem(key: "run", title: "Run", syncState: .pendingCreate)
        )
        let adapter = SyncFixtures.sqlAdapter { request in
            if !request.upserts.isEmpty {
                return SyncFixtures.response(
                    applied: [.fixture(key: "run", id: 101, status: "created")],
                    fullResyncRequired: true
                )
            }
            return SyncFixtures.response(
                mode: "full",
                serverChanges: [
                    ItemChange(key: "run", title: "Run", serverId: 101, isDeleted: false)
                ],
                cursor: "fresh"
            )
        }

        try await SyncEngine(store: store).sync(adapter)

        let remaining = try await rows(store)
        #expect(remaining.map(\.key) == ["run"])
        #expect(remaining.first?.syncState == .synced)
        #expect(remaining.first?.serverId == 101)
        #expect(try await checkpoint(store)?.cursor == "fresh")
    }

    @Test func failedPageRollsBackRowsAcksAndCursorTogether() async throws {
        let store = try SQLiteSyncStore()
        try await seed(store, SQLItem(key: "run", title: "Run", syncState: .pendingCreate))
        try await store.transaction { connection in
            try store.saveCheckpoint(SyncCheckpoint(cursor: "c0"), for: "items", in: connection)
        }
        let adapter = SyncFixtures.sqlAdapter(failingTitle: "Boom") { _ in
            SyncFixtures.response(
                applied: [.fixture(key: "run", id: 101, status: "created")],
                serverChanges: [
                    ItemChange(key: "alpha", title: "Alpha", serverId: 1, isDeleted: false),
                    ItemChange(key: "beta", title: "Boom", serverId: 2, isDeleted: false),
                ],
                cursor: "c1"
            )
        }

        await #expect(throws: SQLiteError(message: "rejected beta")) {
            try await SyncEngine(store: store).sync(adapter)
        }

        let remaining = try await rows(store)
        #expect(remaining.map(\.key) == ["run"])
        #expect(remaining.first?.syncState == .pendingCreate)
        #expect(remaining.first?.serverId == nil)
        #expect(try await checkpoint(store)?.cursor == "c0")
    }

    @Test func blockedAckIsReportedAfterThePageCommits() async throws {
        let store = try SQLiteSyncStore()
        try await seed(store, SQLItem(key: "b", title: "B", syncState: .pendingCreate))
        let blockedStates = Box<[SyncState?]>([])
        let adapter = SyncFixtures.sqlAdapter { _ in
            SyncFixtures.response(
                applied: [.fixture(key: "b", status: "blocked", reason: "quota")])
        }
        let engine = SyncEngine(
            store: store,
            events: { event in
                guard case .itemBlocked = event else { return }
                let state = try? await store.transaction { try $0.item(key: "b")?.syncState }
                await MainActor.run { blockedStates.value.append(state ?? nil) }
            }
        )

        try await engine.sync(adapter)

        #expect(blockedStates.value == [.blocked])
    }
}
