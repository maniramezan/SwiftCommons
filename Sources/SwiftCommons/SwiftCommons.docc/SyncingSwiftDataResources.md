# Syncing SwiftData Resources

Plug a SwiftData model into ``SyncEngine`` with one ``SyncResourceAdapter``, and let the engine
own the sync contract.

## Overview

``SyncEngine`` runs one generic loop for every synced resource. A pass pushes local changes,
applies the server's acknowledgements, ingests server changes page by page, and — when the
server sends a full snapshot — tombstones rows the snapshot no longer contains. Resource
specifics (fetching rows, building wire payloads, calling the transport, applying changes) come
from the adapter; the invariants below live in the engine so no resource can skip one.

### Prepare the model

Conform your `@Model` to ``SyncableModel`` by storing its bookkeeping fields:

```swift
@Model final class Item: SyncableModel {
    var key: String
    var title: String
    var serverId: Int?
    var updatedAt: Date
    var isTombstoned: Bool
    var syncState: SyncState
    var localUpdatedAt: Date
    // init ...
}
```

- Important: Never name the soft-delete flag `isDeleted` on a `@Model`. `PersistentModel`
  already defines `isDeleted` (the context's hard-delete state), which shadows your stored
  property, so writes don't read back.

When the app edits a row locally, set ``SyncableModel/syncState`` to the matching `pending*`
case and bump ``SyncableModel/localUpdatedAt`` to the current date. The engine uses that date as
the *ack guard*: an acknowledgement is only applied if the row hasn't been edited again since it
was pushed.

### Include SyncMetadata in the schema

The engine stores each resource's cursor in a ``SyncMetadata`` row, so the container's schema
must include it:

```swift
let container = try ModelContainer.make(for: Item.self, SyncMetadata.self)
```

``SyncMetadata`` declares `resourceName` with `@Attribute(.unique)`, which CloudKit-backed
stores don't support. Keep it in a local store.

### Write the adapter

| Closure | Responsibility |
|---|---|
| `fetchPending` | Rows whose `syncState` isn't `.synced`. |
| `businessKey` | The row's stable key. Must equal the server's `applied[].key` and `changeKey`. |
| `makeUpserts` / `makeDeletes` | Wire payloads for pending rows (split on `isTombstoned`). |
| `call` | The transport: send a ``SyncRequestDTO``, return a ``SyncResponseDTO``. |
| `findExisting` | The local row a server change refers to. |
| `changeKey` / `isChangeDeleted` | Key and deletion flag of a server change. |
| `upsertFromChange` | Apply a change to the existing row, or insert a new one, and mark it `.synced`. |
| `fetchActive` | Every non-tombstoned row, for full-snapshot reconciliation. |
| `purgeSynced` | Delete `.synced` rows before a full resync. |

### What the engine guarantees

- **Pending guard:** a server change never overwrites a row that still has unpushed local
  changes.
- **Ack guard:** acknowledgements for rows edited mid-flight are skipped; the row is pushed
  again next pass.
- **Full-resync recovery:** when the server reports `fullResyncRequired`, synced rows and the
  cursor are dropped and a fresh snapshot is pulled. Acknowledgements from the push are kept.
- **Snapshot reconciliation:** after all pages of a full snapshot, clean rows absent from it are
  tombstoned. The cursor is committed only once that completes, so a failed page restarts the
  snapshot instead of resuming as a delta.
- **Serialization:** passes run under an ``AsyncLock``; share one lock across engines that must
  not overlap.

Sync several resources with ``SyncEngine/syncAll(_:)`` by wrapping each adapter in
``AnySyncResource``. Resources are isolated: one failing doesn't stop the others, and the first
error is rethrown at the end.

### Observe and test

Pass an `events` handler to forward ``SyncEvent`` values to analytics or logging.

In tests, add the `SwiftCommonsTestSupport` product and use `makeInMemorySyncContainer(for:)`
(which adds ``SyncMetadata`` for you), `SyncResponseDTO.fixture(...)`,
`SyncAppliedDTO.fixture(...)`, and `recordingCall(returning:into:)` to script the transport and
capture requests.
