---
name: swiftcommons-testing
description: Use when writing Swift Testing tests for code built on SwiftCommons — time-dependent code using withRetry or Debouncer, LoadingState results, SwiftData models, or SyncEngine resources — via the SwiftCommonsTestSupport product (ManualClock, expectLoaded/expectFailed, makeInMemoryModelContext, makeInMemorySyncContainer, Box, recordingCall, DTO fixtures).
---

# Testing with SwiftCommonsTestSupport

Add the product to **test targets only**. It depends on `Testing`, and it must never be linked
into app targets.

```swift
.testTarget(name: "MyAppTests", dependencies: [
    "MyApp",
    .product(name: "SwiftCommonsTestSupport", package: "SwiftCommons"),
])
```

## Time: `ManualClock`

`withRetry` and `Debouncer` accept a `clock:`. In tests, inject the fake clock so no test sleeps
in real time.

```swift
let clock = ManualClock()
let task = Task { try await withRetry(attempts: 3, delay: .seconds(5), clock: clock) { try await flaky() } }

while await clock.waiterCount == 0 { await Task.yield() }   // wait until the sleep is registered
await clock.advance(by: .seconds(5))
```

Always poll `waiterCount` before `advance(by:)`. Advancing before the code under test has
registered its sleep has no effect, and the test hangs or flakes. Production code should keep the
default clock parameter; only tests pass one in.

## `LoadingState`

```swift
let items = try #require(expectLoaded(await viewModel.load()))   // records an issue if not .loaded
let error = expectFailed(state)                                  // returns LoadingError?
#expect(error?.isRetryable == true)
```

A cancelled `LoadingState.load` returns `.idle`. Assert `== .idle` for cancellation paths.

## SwiftData

```swift
let context = try makeInMemoryModelContext(for: Item.self, Tag.self)   // fresh store per call
```

For previews or app bootstrap (not tests), use `ModelContainer.make(for:inMemory:)` from
`SwiftCommons`.

## Capturing from `@Sendable` closures

```swift
let calls = Box<[Request]>([])          // @MainActor; run the test on the main actor
let call = recordingCall(returning: response, into: calls)
```

## Sync

```swift
let container = try makeInMemorySyncContainer(for: Item.self)   // SyncMetadata included
let response = SyncResponseDTO<ItemChange>.fixture(
    mode: "full", serverChanges: [change], cursor: "c1", hasMore: false)
let ack = SyncAppliedDTO.fixture(key: "item-1", id: 42, status: "created")
```

Mark sync tests `@MainActor`, because `SyncEngine` and `SyncResourceAdapter` are main-actor
isolated. The `swiftcommons-sync` skill lists which behaviors to cover.

## Conventions

- Use Swift Testing (`@Test`, `#expect`, `#require`), not XCTest.
- Use descriptive names, including in fixtures (`firstFormatter`, not `f1`).
