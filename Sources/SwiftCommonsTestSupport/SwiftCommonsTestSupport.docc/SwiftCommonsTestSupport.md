# ``SwiftCommonsTestSupport``

Test-only helpers for code that uses SwiftCommons.

## Overview

Add the `SwiftCommonsTestSupport` product to your test targets only. It provides a fake clock for
the `DelayClock`-driven APIs, assertions for `LoadingState`, in-memory SwiftData helpers, and
fixtures for the sync DTOs. It never contains app-facing APIs.

```swift
import SwiftCommons
import SwiftCommonsTestSupport
import Testing

let clock = ManualClock()
let debouncer = Debouncer(delay: .seconds(1), clock: clock)
await debouncer.run { /* action under test */ }
try #require(await clock.waitForSleepCount(1))
await clock.advance(by: .seconds(1))

let state = await LoadingState.load { try await fetchItems() }
expectLoaded(state)
```

### Testing sync

``makeInMemorySyncContainer(for:)`` builds a container whose schema already includes
`SyncMetadata`. `SyncResponseDTO.fixture(...)` and `SyncAppliedDTO.fixture(...)` build DTOs with
test defaults, and ``recordingCall(returning:into:)`` records the requests a
`SyncResourceAdapter`'s `call:` closure receives.

## Topics

### Clocks

- ``ManualClock``

### Assertions

- ``expectLoaded(_:sourceLocation:)``
- ``expectFailed(_:sourceLocation:)``

### SwiftData

- ``makeInMemoryModelContext(for:)``
- ``makeInMemorySyncContainer(for:)``

### Recording calls

- ``Box``
- ``recordingCall(returning:into:)``
