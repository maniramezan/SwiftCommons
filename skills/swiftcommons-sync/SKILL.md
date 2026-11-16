---
name: swiftcommons-sync
description: Use when adding, changing, or debugging offline sync with SwiftCommons' SyncEngine — conforming a SwiftData @Model (or a GRDB/SQLite row struct) to SyncableModel, writing a SyncResourceAdapter, choosing or implementing a SyncStore, marking local edits as pending, wiring the transport, migrating from the @MainActor engine (0.17 and earlier), or testing a sync resource.
---

# SwiftCommons sync: adding a resource

`SyncEngine<Store>` owns the whole sync contract: pending guard, ack guard, pagination,
full-snapshot reconciliation, and full-resync recovery. Adding a resource means writing **one**
`SyncResourceAdapter`. Don't re-implement any of that logic in the adapter or the app.

The engine isn't bound to the main actor. Local reads and writes run inside the `SyncStore`'s
transactions, wherever the store runs them; each page's rows and cursor commit together.

| Store | Where it runs | Use |
|---|---|---|
| `SwiftDataSyncStore` (via `SyncEngine(modelContainer:)`) | main actor, `mainContext` | SwiftUI views see each page as it lands |
| `SwiftDataBackgroundSyncStore(modelContainer:)` | its own `@ModelActor` context | large syncs off the main thread; a failed page rolls back |
| your own `SyncStore` | wherever you choose | GRDB, SQLite, Core Data. See the *Syncing Custom Stores* DocC article |

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
func notesAdapter(
    call: @escaping @Sendable (SyncRequestDTO<NoteUpsert, NoteDelete>) async throws -> SyncResponseDTO<NoteChange>
) -> SwiftDataSyncAdapter<Note, NoteUpsert, NoteDelete, NoteChange> {
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
- Every closure is `@Sendable`. All of them except `call` run inside the store's transaction, so
  don't touch main-actor state from them. `call` runs outside it; when it needs main-actor state,
  write it as `{ @MainActor request in … }`.
- SwiftData adapters take no `persist:`. For value-type rows (GRDB, SQLite), use the general
  `SyncResourceAdapter<…, Database>` init and pass `persist: { row, db in try row.save(db) }`, or
  the engine's ack and tombstone writes are lost. `upsertFromChange` writes its own row.
- `businessKey`, the server's `applied[].key`, and `changeKey` must produce the **same** string
  for the same row. Normalize case and whitespace in all three.
- `upsertFromChange` must leave the row `.synced`.
- For pages of many changes, pass `findExistingBatch: { changes, context in … }` (a `[String: Note]`
  keyed by `changeKey`, from one fetch) so the engine doesn't fetch once per change. `findExisting`
  is still required and is used for keyless or repeated-key changes.
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
  the app resolves them. Surface `SyncEvent.itemBlocked` to the user. It arrives after the page that
  carried the ack is saved.
- `AnySyncResource` is generic over the store. Type inference handles `SyncEngine(modelContainer:)`,
  but for a background engine pass the array straight to `syncAll`, or spell
  `AnySyncResource<SwiftDataBackgroundSyncStore>(adapter)`.

## Migrating from 0.17 (`@MainActor` engine)

- `SyncResourceAdapter<A, B, C, D>` → `SwiftDataSyncAdapter<A, B, C, D>`; a stored
  `let engine: SyncEngine` → `SwiftDataSyncEngine`. `SyncEngine(modelContainer:)` and the adapter
  initializer without `persist:` are unchanged.
- Adapter closures are now `@Sendable`. A `call:` that captures main-actor state becomes
  `{ @MainActor request in … }`, or a call to a `@MainActor` async function.
- `upsertFromChange` may now throw. Throwing fails the pass and leaves the cursor unchanged.
- `SyncableModel` no longer requires `AnyObject` and now refines `SendableMetatype`. `@Model`
  classes conform unchanged, including in modules with default `MainActor` isolation.

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
overwritten by a server change; a full snapshot tombstones absent rows. For a custom store, also
check that a throwing page rolls back its rows, acks, and cursor together.
