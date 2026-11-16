# Syncing Custom Stores

Run ``SyncEngine`` over GRDB, raw SQLite, Core Data, or any other store by implementing
``SyncStore``.

## Overview

The engine never talks to a database directly. Every step of a pass that reads or writes local
data runs inside one ``SyncStore/transaction(_:)``, and only `Sendable` values — request and
response DTOs, the pushed rows' `localUpdatedAt` values, and active keys — cross the network
calls between transactions. Rows never leave a transaction, so they don't need to be `Sendable`
and can be classes or value types.

A pass runs these transactions:

1. Read the ``SyncCheckpoint`` and the pending rows, and build the push request.
2. On `fullResyncRequired`, purge synced rows and clear the cursor.
3. Apply the push acknowledgements, ingest the first page, and write the checkpoint.
4. For each further page, ingest it and write the checkpoint.
5. After a full snapshot, tombstone absent rows and commit the final cursor.

The network calls happen between these transactions, never inside one.

### Implement the store

```swift
public protocol SyncStore: Sendable {
    associatedtype Context
    func transaction<T: Sendable>(_ body: @Sendable (Context) throws -> T) async throws -> T
    func checkpoint(for resourceName: String, in context: Context) throws -> SyncCheckpoint?
    func saveCheckpoint(_ checkpoint: SyncCheckpoint, for resourceName: String, in context: Context) throws
}
```

- **Atomicity:** row writes and the checkpoint written through the same `context` must commit
  together, or not at all when `body` throws. The checkpoint can only be written through a
  transaction's `context`, so a cursor can never be saved apart from the rows it describes.
- **Isolation:** the store decides where `body` runs — the main actor, its own actor, or a
  serial queue. The engine itself isn't bound to any actor.

With GRDB, `DatabaseWriter.write(_:)` already has this shape and rolls back on throw:

```swift
struct GRDBSyncStore: SyncStore {
    let writer: any DatabaseWriter

    func transaction<T: Sendable>(_ body: @Sendable (Database) throws -> T) async throws -> T {
        try await writer.write(body)
    }

    func checkpoint(for resourceName: String, in db: Database) throws -> SyncCheckpoint? {
        try CheckpointRecord.fetchOne(db, key: resourceName)?.checkpoint
    }

    func saveCheckpoint(_ checkpoint: SyncCheckpoint, for resourceName: String, in db: Database) throws {
        try CheckpointRecord(resourceName: resourceName, checkpoint: checkpoint).save(db)
    }
}
```

`CheckpointRecord` is your own table with a column per ``SyncCheckpoint`` field.

### Write back engine changes with persist

Conform your row type to ``SyncableModel``. A `struct` works:

```swift
struct Note: SyncableModel, Codable, FetchableRecord, PersistableRecord {
    var key: String
    var body: String
    var serverId: Int?
    var updatedAt: Date
    var isTombstoned: Bool
    var syncState: SyncState
    var localUpdatedAt: Date
}
```

The engine changes rows when it applies an acknowledgement and when it tombstones a row absent
from a full snapshot. It changes a copy, so the adapter's
``SyncResourceAdapter/persist`` closure must write that copy back:

```swift
let notes = SyncResourceAdapter<Note, NoteUpsert, NoteDelete, NoteChange, Database>(
    resourceName: "notes",
    fetchPending: { try Note.filter(Column("syncState") != SyncState.synced.rawValue).fetchAll($0) },
    businessKey: { $0.key },
    makeUpserts: { $0.filter { !$0.isTombstoned }.map(NoteUpsert.init) },
    makeDeletes: { $0.filter(\.isTombstoned).map(NoteDelete.init) },
    call: { try await api.sync("notes", $0) },
    findExisting: { change, db in try Note.fetchOne(db, key: change.key) },
    changeKey: { $0.key },
    isChangeDeleted: { $0.deleted },
    upsertFromChange: { change, existing, db in
        var note = existing ?? Note(key: change.key)
        note.body = change.body
        note.serverId = change.id
        note.isTombstoned = change.deleted
        note.syncState = .synced
        try note.save(db)
    },
    fetchActive: { try Note.filter(Column("isTombstoned") == false).fetchAll($0) },
    purgeSynced: { try Note.filter(Column("syncState") == SyncState.synced.rawValue).deleteAll($0) },
    persist: { note, db in try note.save(db) }
)

let engine = SyncEngine(store: GRDBSyncStore(writer: dbQueue))
try await engine.sync(notes)
```

`upsertFromChange` writes its own row, and throwing from it rolls back the whole page,
including the page's acknowledgements and checkpoint.

### What changes from the SwiftData flow

- **Ack guard:** the engine re-reads the pending rows inside the acknowledgement transaction
  and compares each row's current `localUpdatedAt` with the value it pushed. Rows edited, or
  deleted, while the request was in flight are skipped and pushed again next pass.
- **Events:** ``SyncEvent/itemBlocked(resource:status:reason:)`` is emitted after the page that
  carried the acknowledgement commits.
- **The transport:** `call` runs outside any transaction. Every other adapter closure runs inside
  one, wherever the store runs it, so don't touch main-actor state from them.

The guarantees listed in <doc:SyncingSwiftDataResources> hold for every store.
