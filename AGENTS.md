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

- `Sources/SwiftCommons/Extensions`: Foundation extensions (Array, Optional, URL, String, Bundle, FixedWidthInteger, Locale, NumberFormatter)
- `Sources/SwiftCommons/Dates`: Date/time utilities (Calendar extensions, DateFormatter cache)
- `Sources/SwiftCommons/Locales`: `Language`, `Country`, and locale identifier helpers
- `Sources/SwiftCommons/Logging`: OSLog `Logger` helpers and SwiftCommons subsystem
- `Sources/SwiftCommons/Formatters`: `DurationFormatter` for human-readable durations
- `Sources/SwiftCommons/State`: `LoadingState<Value>` async data-loading state machine
- `Sources/SwiftCommons/Configuration`: `ConfigValue` for lenient cross-type config coercion
- `Sources/SwiftCommons/Concurrency`: `AsyncLock`, `Debouncer`, and `withRetry(...)`
- `Sources/SwiftCommons/Sync`: generic SwiftData sync engine (`SyncEngine`, `SyncResourceAdapter`, `SyncableModel`, `SyncMetadata`, DTOs)
- `Tests/SwiftCommonsTests`: Swift Testing coverage mirroring the `Sources` structure

## Key APIs and Patterns

- Safe array access with optional or defaulted subscripts (`Array+Extensions`).
- `Optional.ifNil(_:)` for defaulting optionals.
- `String.trimmed`, `.isBlank`, `.nilIfBlank` for normalizing text input.
- `Bundle.appVersion`, `.buildNumber`, `.versionAndBuildNumber` for app version display.
- `URL` adopts `ExpressibleByStringLiteral` using `@retroactive` (Swift 6).
- `DateFormatter.formatter(...)` caches per-thread instances via `Thread.current.threadDictionary`.
- `Calendar` extensions provide date math (start of week/month, month symbols, adding months/years).
- `Language` and `Country` enums are curated ISO code subsets (not exhaustive).
- `Locale.identifier(language:country:)` plus `Locale.Identifiers` convenience constants.
- Logging helpers built on OSLog with public/private convenience methods and context helpers.
- `DurationFormatter.format(seconds:)` renders compact `m:ss` / `h:mm:ss` durations.
- `LoadingState<Value>` models idle/loading/loaded/failed screen state; `LoadingState.load { ... }`
  runs a throwing async operation and maps the outcome; `LoadingError(from:)` redacts internal
  error details behind a generic, user-safe message.
- `ConfigValue` is a `bool`/`string`/`int`/`double` enum with lenient coercion accessors
  (`boolValue`, `stringValue`, `intValue`, `doubleValue`).
- `AsyncLock` is a FIFO async mutex for serializing work across `await` suspension points.
- `Debouncer` (actor) coalesces rapid repeated calls into one action after a quiet period.
- `withRetry(attempts:delay:operation:)` retries a throwing async operation with a fixed delay.
- `SyncEngine` (`@MainActor`) drives offline sync for SwiftData `@Model` rows conforming to `SyncableModel`; each resource plugs in via a `SyncResourceAdapter` (struct of closures) and the engine owns the contract (ack guard, pending guard, full-snapshot reconciliation, pagination drain, full-resync recovery).
- `SyncableModel` requires `isTombstoned`, NOT `isDeleted`: on a SwiftData `@Model` a stored `isDeleted` is shadowed by `PersistentModel.isDeleted` (context hard-delete state), so writes don't read back on the live object. Never name a soft-delete flag `isDeleted` on a `@Model`.

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
- Tests: `Tests/SwiftCommonsTests/`

## Planning

- Use `Plan.md` for task planning and progress tracking when the work is non-trivial.

## When Updating

- Add or update tests under `Tests/SwiftCommonsTests` for behavior changes.
- If you discover repo-wide guidance helpful to other agents, add it here (not in `CLAUDE.md`).
