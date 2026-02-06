# CLAUDE.md

Shared repository guidance for all agents (Codex, Claude, etc.). Keep this file focused on repo-wide facts and conventions that help any agent.

## Project Overview

SwiftCommons is a Swift Package Manager library providing Foundation extensions and utilities. It targets macOS 13+, iOS 16+, and Mac Catalyst 16+. The package uses Swift 6 language mode (`swift-tools-version: 6.2`) and has no external dependencies.

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

- `Sources/SwiftCommons/Extensions`: Foundation extensions (Array, Optional, URL, FixedWidthInteger, Locale, NumberFormatter)
- `Sources/SwiftCommons/Dates`: Date/time utilities (Calendar extensions, DateFormatter cache)
- `Sources/SwiftCommons/Locales`: `Language`, `Country`, and locale identifier helpers
- `Sources/SwiftCommons/Logging`: OSLog `Logger` helpers and SwiftCommons subsystem
- `Tests/SwiftCommonsTests`: XCTest coverage for extensions and date utilities

## Key APIs and Patterns

- Safe array access with optional or defaulted subscripts (`Array+Extensions`).
- `Optional.ifNil(_:)` for defaulting optionals.
- `URL` adopts `ExpressibleByStringLiteral` using `@retroactive` (Swift 6).
- `DateFormatter.formatter(...)` caches per-thread instances via `Thread.current.threadDictionary`.
- `Calendar` extensions provide date math (start of week/month, month symbols, adding months/years).
- `Language` and `Country` enums are curated ISO code subsets (not exhaustive).
- `Locale.identifier(language:country:)` plus `Locale.Identifiers` convenience constants.
- Logging helpers built on OSLog with public/private convenience methods and context helpers.

## Conventions

- 4-space indentation and doc comments on public APIs are the norm.
- Small, self-contained helpers often use `@inlinable` to match existing style.
- Avoid adding new dependencies without discussion; keep the library lightweight.

## When Updating

- Add or update tests under `Tests/SwiftCommonsTests` for behavior changes.
- If you discover repo-wide guidance helpful to other agents, add it here.
