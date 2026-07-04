# ``SwiftCommons``

Foundation extensions and small, dependency-free utilities for reusable app code.

## Overview

SwiftCommons is a lightweight Swift Package Manager library of Foundation
extensions and helpers used across Apple-platform apps. It has no external
runtime dependencies, builds in Swift 6 language mode, and targets macOS 14+,
iOS 17+, and Mac Catalyst 17+.

```swift
import SwiftCommons

// Safe, defaulted collection access
let first = [1, 2, 3][safe: 10]            // nil
let fallback = ["a", "b"][5, default: "?"] // "?"

// Cached, thread-safe formatters
let formatter = DateFormatter.formatter(.MMMMddyyyy)
let text = formatter.string(from: Date())

// Locale building blocks
let id = Locale.identifier(language: .french, country: .canada) // "fr-CA"
```

### What's included

- **Collections & optionals** — safe and defaulted subscripts on `Array`
  (`[safe:]`, `[_, default:]`, and range variants) and `Optional.ifNil(_:)`.
- **Strings, Bundle, UUID, Duration** — `String.trimmed`/`.isBlank`/`.nilIfBlank`,
  `Bundle.appVersion`/`.buildNumber`/`.versionAndBuildNumber`, `UUID` byte and
  deterministic-generation helpers, and `Duration.timeInterval`.
- **Numbers** — `FixedWidthInteger.digits` and locale-aware
  `NumberFormatter` helpers (`formatYear`, `formatDay`, `formatCurrency`).
- **Dates & calendars** — `Calendar` date math (start of week/month, month
  symbols, month/year arithmetic, inclusive date ranges via `dates(from:through:)`),
  a thread-safe `DateFormatter.formatter(_:)` cache, and
  `Date.relativeDescription(to:unitsStyle:locale:)` for human-readable relative
  times (e.g. "1 hour ago").
- **Localization** — the ``Language`` and ``Country`` enums plus `Locale`
  identifier helpers (`Locale.identifier(language:country:)`,
  `Locale.Identifiers`, and `withNumberingSystemIdentifier(_:)`).
- **Logging** — OSLog `Logger` conveniences for category creation, privacy
  levels, and error/context logging.
- **State & configuration** — a generic ``LoadingState`` machine with
  ``LoadingError`` for async fetches (including ``LoadingState/load(_:)`` to
  wrap a throwing async operation), and a coercing ``ConfigValue`` with
  loaders for the process environment and decoded property lists.
- **Concurrency** — ``AsyncLock`` (FIFO mutex), ``AsyncSemaphore`` (counting
  semaphore), ``Debouncer``, and ``withRetry(attempts:delay:clock:operation:)``,
  all built on the injectable ``SwiftCommonsClock`` abstraction.
- **CSV** — lightweight CSV parsing/serialization, gated behind the `CSV`
  package trait.
- **Persistence** — `ModelContainer.make(for:inMemory:)`, a thin SwiftData
  bootstrap helper for apps, previews, and tests.
- **Formatting** — ``DurationFormatter`` for compact `m:ss` / `h:mm:ss`
  durations.
- **Sync** — a generic ``SyncEngine`` that drives offline, cross-device sync
  for SwiftData-backed resources through one contract-owning loop; resources
  plug in as ``SyncResourceAdapter`` values.

A separate `SwiftCommonsTestSupport` product ships test-only helpers (a fake
clock, `LoadingState` assertions, an in-memory SwiftData context helper, and
generic sync test fixtures) for consumers' test targets.

Foundation, Swift standard library, and OSLog extensions are listed under
**Extensions** below.

## Topics

### Localization

- ``Language``
- ``Country``

### State & Configuration

- ``LoadingState``
- ``LoadingError``
- ``ConfigValue``

### Concurrency

- ``AsyncLock``
- ``AsyncSemaphore``
- ``Debouncer``
- ``withRetry(attempts:delay:clock:operation:)``
- ``SwiftCommonsClock``
- ``ContinuousSwiftCommonsClock``

### Formatting

- ``DurationFormatter``

### Sync

- ``SyncEngine``
- ``SyncResourceAdapter``
- ``AnySyncResource``
- ``SyncableModel``
- ``SyncState``
- ``SyncMetadata``
- ``SyncEvent``
- ``SyncRequestDTO``
- ``SyncResponseDTO``
- ``SyncAppliedDTO``
