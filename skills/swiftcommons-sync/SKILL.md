---
name: swiftcommons-sync
description: Use when adding, changing, or debugging offline sync of a SwiftData model with SwiftCommons' SyncEngine — conforming a @Model to SyncableModel, writing a SyncResourceAdapter, marking local edits as pending, wiring the transport, or testing a sync resource.
---

# SwiftCommons sync: adding a resource

`SyncEngine` (`@MainActor`) owns the whole sync contract: pending guard, ack guard, pagination,
full-snapshot reconciliation, and full-resync recovery. Adding a resource means writing **one**
`SyncResourceAdapter`. Don't re-implement any of that logic in the adapter or the app.

## 1. Model

```swift
@Model final class Note: SyncableModel {
    var key: String              // stable business key shared with the server
    var body: String
    var serverId: Int?
    var updatedAt: Date          // last server updatedAt seen
    var isTombstoned: Bool       // soft delete — NEVER name this `isDeleted` on a @Model
    var syncState: SyncState     // .synced / .pendingCreate / .pendingUpdate / .pendingDelete / .blocked
    var localUpdatedAt: Date     // ack-guard pivot
    // init ...
}
```

A SwiftData `@Model` already has `isDeleted` (from `PersistentModel`), and it shadows a stored
property with that name.

## 2. Local mutations: always mark pending

```swift
note.body = newBody
note.syncState = note.serverId == nil ? .pendingCreate : .pendingUpdate
note.localUpdatedAt = .now

// delete
note.isTombstoned = true
note.syncState = .pendingDelete
note.localUpdatedAt = .now
```

Skip the `localUpdatedAt` bump and the ack guard can't tell that the row was edited while its
push was in flight.

## 3. Schema

`SyncMetadata` must be in the container. It uses `@Attribute(.unique)`, so keep it in a local
store, not a CloudKit-backed one.

```swift
let container = try ModelContainer.make(for: Note.self, SyncMetadata.self)
```

## 4. Adapter

```swift
@MainActor
func notesAdapter(
    call: @escaping (SyncRequestDTO<NoteUpsert, NoteDelete>) async throws -> SyncResponseDTO<NoteChange>
) -> SyncResourceAdapter<Note, NoteUpsert, NoteDelete, NoteChange> {
    SyncResourceAdapter(
        resourceName: "notes",                                   // also keys SyncMetadata
        fetchPending: { try $0.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.syncState != .synced })) },
        businessKey: { $0.key },                                 // == server applied[].key == changeKey
        makeUpserts: { $0.filter { !$0.isTombstoned }.map(NoteUpsert.init) },
        makeDeletes: { $0.filter(\.isTombstoned).map(NoteDelete.init) },
        call: call,                                              // transport seam, injected for tests
        findExisting: { change, context in
            let key = change.key
            return try context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.key == key })).first
        },
        changeKey: { $0.key },
        isChangeDeleted: { $0.deleted },
        upsertFromChange: { change, existing, context in
            let note = existing ?? { let n = Note(key: change.key); context.insert(n); return n }()
            note.body = change.body
            note.serverId = change.id
            note.isTombstoned = change.deleted
            note.syncState = .synced                             // required
        },
        fetchActive: { try $0.fetch(FetchDescriptor<Note>(predicate: #Predicate { !$0.isTombstoned })) },
        purgeSynced: { try $0.delete(model: Note.self, where: #Predicate { $0.syncState == .synced }) }
    )
}
```

Rules:
- `businessKey`, the server's `applied[].key`, and `changeKey` must produce the **same** string
  for the same row. Normalize case and whitespace in all three.
- `upsertFromChange` must leave the row `.synced`.
- `purgeSynced` deletes only `.synced` rows. Pending rows must survive a full resync.

## 5. Run

```swift
let engine = SyncEngine(modelContainer: container, events: { event in analytics.track(event) })
let notes = notesAdapter(call: { try await api.sync("notes", $0) })
let tags = tagsAdapter(call: { try await api.sync("tags", $0) })
try await engine.syncAll([AnySyncResource(notes), AnySyncResource(tags)])
```

- Engines that must not overlap should share one `AsyncLock` (the `lock:` init parameter).
- `syncAll` isolates resources: it runs every resource, then rethrows the first error.
- `.blocked` rows (the server returned `blocked` / `rejected`) never receive server changes until
  the app resolves them. Surface `SyncEvent.itemBlocked` to the user.

## Wire contract (server side)

- Request: `{ since, limit, upserts, deletes }`.
- Response: `{ syncVersion, mode: "full" | <delta>, applied: [{ key, id?, status, updatedAt?, reason? }], serverChanges, cursor?, hasMore, fullResyncRequired, serverInfo? }`.
- `status` is one of `created`, `updated`, `deleted`, `noop`, `blocked`, `rejected`.
- `updatedAt` is in seconds since 1970.
- `serverInfo` (`[String: String]`) is copied to `SyncMetadata.serverInfo`. Use it for policy
  values such as quotas.

## Testing

```swift
import SwiftCommonsTestSupport

let container = try makeInMemorySyncContainer(for: Note.self)   // adds SyncMetadata
let requests = Box<[SyncRequestDTO<NoteUpsert, NoteDelete>]>([])
let adapter = notesAdapter(call: recordingCall(
    returning: SyncResponseDTO<NoteChange>.fixture(
        applied: [.fixture(key: "n1", id: 1, status: "created")], cursor: "c1"),
    into: requests))
try await SyncEngine(modelContainer: container).sync(adapter)
#expect(requests.value.first?.upserts.count == 1)
```

Cover at least: create ack sets `serverId`; edit during flight is re-pushed; a pending row isn't
overwritten by a server change; a full snapshot tombstones absent rows.
