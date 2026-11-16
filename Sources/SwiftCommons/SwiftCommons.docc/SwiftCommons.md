# ``SwiftCommons``

Foundation extensions and small, dependency-free utilities for reusable app code.

## Overview

SwiftCommons is a lightweight Swift Package Manager library of Foundation
extensions and helpers used across Apple-platform apps. It has no external
runtime dependencies, builds in Swift 6 language mode, and targets macOS 15+,
iOS 18+, and Mac Catalyst 18+.

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
  the ``StringParsable`` protocol (`T(parsing:)` with a lenient `Bool` parser)
  and `String(flag:)`/`.enabledFlag`/`.disabledFlag` boolean-flag helpers,
  `String.ensuringStarts(with:)`, suffix trimming (`trimmingSuffix(while:)`,
  `trimmingSuffix(_:)` for a sequence or regex, and the mutating `trimSuffix` overloads),
  `Character.isAlphanumeric`, `Bundle.appVersion`/`.buildNumber`/`.versionAndBuildNumber`, `UUID`
  byte and deterministic-generation helpers, and `Duration.timeInterval`.
- **Decoding diagnostics** — `DecodingError.debugSummary` renders the failure kind, key or type, and
  coding path (`keyNotFound 'id' at items[2].user`) without decoded values, for safe logging.
- **Numbers** — `FixedWidthInteger.digits` and locale-aware
  `NumberFormatter` helpers (`formatYear`, `formatDay`, `formatOrdinal`, `formatCurrency`,
  `formatDecimal`, `formatPercent`), plus `MeasurementFormatter.cached(unitStyle:unitOptions:locale:)`.
- **Dates & calendars** — ``MonthIdentifier`` and ``CalendarArithmetic`` preserve
  era and leap-month identity without application date limits. ``CalendarArithmetic/gridDates(in:)``
  pads a month to complete weeks of day starts. These sit alongside `Calendar` date math (start of week/month, month
  symbols, month/year arithmetic, inclusive date ranges via `dates(from:through:)`),
  a thread-local date formatter cache for literal patterns, localized templates, and date/time styles, and
  `Date.relativeDescription(to:unitsStyle:locale:)` for human-readable relative
  times (e.g. "1 hour ago").
- **Localization** — the ``Language`` and ``Country`` enums plus `Locale`
  identifier helpers (`Locale.identifier(language:country:)`,
  `Locale.Identifiers`, and `withNumberingSystemIdentifier(_:)`).
- **Logging** — OSLog `Logger` conveniences for category creation, privacy
  levels, and error/context logging, ``LibraryLogger`` (a level-gated front end whose
  verbosity a library's users control), plus ``SignpostRecorder`` for measuring
  frame-budgeted work with Instruments' os_signpost instrument.
- **Errors** — ``AnySendableError`` snapshots any `Error` as a `Hashable` value (type, domain, code,
  descriptions) for storing or comparing errors.
- **State & configuration** — a generic ``LoadingState`` machine with
  ``LoadingError`` for async fetches (including ``LoadingState/load(_:)`` to
  wrap a throwing async operation). ``LoadingErrorKind`` and ``LoadingErrorClassifiable``
  provide safe failure categories that apps can map to localized copy. A coercing ``ConfigValue`` has
  loaders for the process environment and decoded property lists, plus a
  ``ConfigValueType`` tag and ``ConfigValue/init(string:valueType:)`` for
  decoding a textual value whose type is known separately.
- **Concurrency** — ``AsyncLock`` (FIFO mutex), ``AsyncSemaphore`` (counting
  semaphore), ``AsyncBroadcaster`` (one source to many `AsyncStream`s),
  ``SingleFlight`` (coalesces concurrent identical requests per key),
  ``Debouncer`` (with ``Debouncer/flush()``), ``Throttler``, and ``withRetry(attempts:delay:clock:operation:)`` (or
  ``withRetry(attempts:backoff:clock:shouldRetry:operation:)`` with a ``RetryBackoff`` and a
  retry predicate), all built on the injectable ``DelayClock`` abstraction.
- **Timeouts** — ``withTimeout(_:clock:operation:)`` races an operation against a clock delay,
  throwing ``TimeoutError`` on expiration and awaiting cancellation cleanup of the losing task.
- **App versions** — ``AppVersion`` parses and compares numeric marketing versions, defaulting
  omitted components to zero and ignoring prerelease and build suffixes.
- **CSV** — lightweight CSV parsing/serialization (``CSV``), gated behind the `CSV`
  package trait.
- **Persistence** — `ModelContainer.make(for:inMemory:)`, a thin SwiftData
  bootstrap helper for apps, previews, and tests.
  Behind the default `SwiftData` package trait.
- **Formatting** — ``DurationFormatter`` for compact `m:ss` / `h:mm:ss`
  durations, and ``FormatterCache``, the thread-local cache behind the date, number, relative-time,
  and measurement formatter helpers; use it to cache any other `Formatter`.
- **Sync** — a generic ``SyncEngine`` that drives offline, cross-device sync
  for SwiftData-backed resources through one contract-owning loop; resources
  plug in as ``SyncResourceAdapter`` values. ``SyncEngine``, ``SyncResourceAdapter``, and
  ``SyncMetadata`` are behind the default `SwiftData` trait; the DTOs,
  ``SyncableModel``, ``SyncState``, and ``SyncEvent`` are always available.

A separate `SwiftCommonsTestSupport` product ships test-only helpers (a fake
clock, `LoadingState` assertions, an in-memory SwiftData context helper,
`makeInMemorySyncContainer(for:)`, and `SyncResponseDTO`/`SyncAppliedDTO` `.fixture(...)` builders) for consumers' test targets.

Foundation, Swift standard library, and OSLog extensions are listed under
**Extensions** below.

## Topics

### Guides

- <doc:SyncingSwiftDataResources>

### Parsing

- ``StringParsable``
- ``AppVersion``

### Localization

- ``Language``
- ``Country``

### State & Configuration

- ``LoadingState``
- ``LoadingError``
- ``LoadingErrorKind``
- ``LoadingErrorClassifiable``
- ``ConfigValue``
- ``ConfigValueType``

### Concurrency

- ``AsyncLock``
- ``AsyncSemaphore``
- ``AsyncBroadcaster``
- ``SingleFlight``
- ``Debouncer``
- ``Throttler``
- ``withRetry(attempts:delay:clock:operation:)``
- ``withRetry(attempts:backoff:clock:shouldRetry:operation:)``
- ``RetryBackoff``
- ``withTimeout(_:clock:operation:)``
- ``TimeoutError``
- ``DelayClock``
- ``LiveClock``

### Dates & Calendars

- ``CalendarArithmetic``
- ``MonthIdentifier``

### Formatting

- ``DurationFormatter``
- ``FormatterCache``

### Diagnostics

- ``LibraryLogger``
- ``SignpostRecorder``
- ``AnySendableError``

### CSV

- ``CSV``

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
