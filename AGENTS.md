# AGENTS.md

Primary agent guidance for this repository (Codex, Claude, and any other coding agent). Keep this file focused on repo-wide facts and conventions — this is the source of truth; other agent-instruction files (e.g. `CLAUDE.md`) should just point here.

## Project Overview

SwiftCommons is a Swift Package Manager library providing Foundation extensions and utilities. It targets macOS 14+, iOS 17+, and Mac Catalyst 17+ (SwiftData requires these minimums). The package uses Swift 6 language mode (`swift-tools-version: 6.2`) and has no external dependencies.

## Build and Test

```bash
# Build the package
swift build

# Run all tests
swift test

# Build with verbose output
swift build -v
```

Important: If using Swift development snapshots (6.3-dev), `swift test` may fail with linker errors (`ld: unknown option: -no_warn_duplicate_libraries`). This is a known toolchain bug. Tests work correctly on stable Swift releases.

See `CONTRIBUTING.md` for formatting and documentation conventions, and
`.github/workflows` for CI and Docs workflows.

## Package Structure

- `Sources/SwiftCommons`: the main library (extensions, dates, locales, logging, formatters, state,
  configuration, concurrency, CSV, persistence, sync — see below).
  - `Extensions`: Foundation extensions (Array, Optional, URL, String, Bundle, UUID, Duration, FixedWidthInteger, Locale, NumberFormatter)
  - `Dates`: Date/time utilities (Calendar extensions incl. inclusive date ranges, DateFormatter cache, `Date.relativeDescription(...)`)
  - `Locales`: `Language`, `Country`, and locale identifier helpers
  - `Logging`: OSLog `Logger` helpers and SwiftCommons subsystem
  - `Formatters`: `DurationFormatter` for human-readable durations
  - `State`: `LoadingState<Value>` async data-loading state machine
  - `Configuration`: `ConfigValue` for lenient cross-type config coercion, environment loading, and property-list loading
  - `Concurrency`: `AsyncLock`, `AsyncSemaphore`, `Debouncer`, `withRetry(...)`, and the injectable `SwiftCommonsClock` abstraction
  - `CSV`: lightweight CSV parsing/serialization helpers (behind the `CSV` package trait)
  - `Persistence`: `ModelContainer.make(for:inMemory:)` SwiftData bootstrap helper
  - `Sync`: generic SwiftData sync engine (`SyncEngine`, `SyncResourceAdapter`, `SyncableModel`, `SyncMetadata`, DTOs)
- `Sources/SwiftCommonsTestSupport`: a separate library product with test-only helpers for consumers
  of `SwiftCommons` (fake clock, `LoadingState` assertions, in-memory SwiftData context helper, and
  generic sync test fixtures). Depends on `SwiftCommons`; never add app-facing (non-test) APIs here.
- `Tests/SwiftCommonsTests`: Swift Testing coverage mirroring the `Sources` structure (covers both
  `SwiftCommons` and `SwiftCommonsTestSupport`).

## Key APIs and Patterns

- Safe array access with optional or defaulted subscripts (`Array+Extensions`).
- `Optional.ifNil(_:)` for defaulting optionals.
- `String.trimmed`, `.isBlank`, `.nilIfBlank` for normalizing text input.
- `Bundle.appVersion`, `.buildNumber`, `.versionAndBuildNumber` for app version display.
- `UUID` extensions for byte access and deterministic generation.
- `Duration.timeInterval` bridges `Duration` to `TimeInterval`.
- `URL` adopts `ExpressibleByStringLiteral` using `@retroactive` (Swift 6).
- `DateFormatter.formatter(...)` caches per-thread instances via `Thread.current.threadDictionary`.
- `NumberFormatter.formatYear(_:locale:)`, `.formatDay(_:locale:)`, and `.formatCurrency(_:currencyCode:locale:)`
  cache formatters per-thread and per (purpose, locale) the same way.
- `Date.relativeDescription(to:unitsStyle:locale:)` wraps `RelativeDateTimeFormatter` with the same
  per-thread caching pattern (e.g. "1 hour ago").
- `Calendar` extensions provide date math (start of week/month, month symbols, adding months/years,
  inclusive date ranges via `dates(from:through:)`).
- `Language` and `Country` enums are curated ISO code subsets (not exhaustive).
- `Locale.identifier(language:country:)` plus `Locale.Identifiers` convenience constants.
- Logging helpers built on OSLog with public/private convenience methods and context helpers.
- `DurationFormatter.format(seconds:)` renders compact `m:ss` / `h:mm:ss` durations.
- `LoadingState<Value>` models idle/loading/loaded/failed screen state; `LoadingState.load { ... }`
  runs a throwing async operation and maps the outcome; `LoadingError(from:)` redacts internal
  error details behind a generic, user-safe message.
- `ConfigValue` is a `bool`/`string`/`int`/`double` enum with lenient coercion accessors
  (`boolValue`, `stringValue`, `intValue`, `doubleValue`); `ConfigValue.environment(_:)` loads
  `[String: ConfigValue]` from `ProcessInfo.environment` (or an injected dictionary) for tests;
  `ConfigValue.propertyList(_:)` loads from a decoded plist dictionary, detecting real `Bool`
  values via `CFGetTypeID`/`CFBooleanGetTypeID` since NSNumber bridging makes `0`/`1` respond
  `true` to a naive `as? Bool` check.
- `AsyncLock` is a FIFO async mutex for serializing work across `await` suspension points.
- `AsyncSemaphore` is a counting async semaphore (`wait()`/`signal()`/`withPermit { ... }`) for
  capping concurrent access (e.g. limiting parallel network requests).
- `Debouncer` (actor) coalesces rapid repeated calls into one action after a quiet period.
- `withRetry(attempts:delay:clock:operation:)` retries a throwing async operation with a fixed delay.
- `SwiftCommonsClock` is the injectable clock protocol behind `withRetry` and `Debouncer`'s delays
  (default: `ContinuousSwiftCommonsClock`, backed by `Task.sleep(for:)`). Both APIs default to the
  real clock, so existing call sites are unaffected; tests can inject
  `ManualSwiftCommonsClock` (in `SwiftCommonsTestSupport`) to avoid real-time waits.
- `CSV` provides lightweight CSV parsing/serialization; gated behind the `CSV` package trait to
  keep it opt-in.
- `ModelContainer.make(for:inMemory:)` is a thin bootstrap over `ModelContainer.init(for:configurations:)`
  for the common single-store, persistent-vs-in-memory case (apps, previews, and tests). An
  array-taking overload (`make(for: [any PersistentModel.Type], inMemory:)`) exists for callers that
  only know the model types dynamically.
- `SyncEngine` (`@MainActor`) drives offline sync for SwiftData `@Model` rows conforming to `SyncableModel`; each resource plugs in via a `SyncResourceAdapter` (struct of closures) and the engine owns the contract (ack guard, pending guard, full-snapshot reconciliation, pagination drain, full-resync recovery).
- `SyncableModel` requires `isTombstoned`, NOT `isDeleted`: on a SwiftData `@Model` a stored `isDeleted` is shadowed by `PersistentModel.isDeleted` (context hard-delete state), so writes don't read back on the live object. Never name a soft-delete flag `isDeleted` on a `@Model`.
- `SwiftCommonsTestSupport` (separate product) provides: `ManualSwiftCommonsClock` (fake, manually
  advanced `SwiftCommonsClock` — poll `waiterCount` before calling `advance(by:)` to avoid racing
  against code under test that hasn't registered its sleep yet); `expectLoaded(_:)`/`expectFailed(_:)`
  for asserting on `LoadingState`; `makeInMemoryModelContext(for:)` for a ready-to-use SwiftData
  `ModelContext`; and `Box<Value>` (`@MainActor` mutable capture reference) plus `recordingCall(returning:into:)`
  for recording requests made through a `SyncResourceAdapter`'s `call:` closure in tests.

## Working Agreement

- Keep changes minimal and focused; prefer extending existing patterns over introducing new abstractions.
- Maintain Swift 6 language mode and platform minimums; avoid new dependencies unless explicitly requested.
- Public APIs should include doc comments and follow existing naming and formatting.
- Update or add tests in `Tests/SwiftCommonsTests` for any behavior changes.

## Code Style Notes

- 4-space indentation and clear, concise documentation comments on public APIs.
- Small, self-contained helpers often use `@inlinable` to match existing style.
- Date and number formatting utilities should respect thread-safety constraints and existing caching patterns.
- Avoid adding new dependencies without discussion; keep the library lightweight.

## Common Paths

- Sources: `Sources/SwiftCommons/`
- Test support (separate product): `Sources/SwiftCommonsTestSupport/`
- Tests: `Tests/SwiftCommonsTests/`

## Planning

- Use `Plan.md` for task planning and progress tracking when the work is non-trivial.

## When Updating

- Add or update tests under `Tests/SwiftCommonsTests` for behavior changes.
- If you discover repo-wide guidance helpful to other agents, add it here (not in `CLAUDE.md`).
