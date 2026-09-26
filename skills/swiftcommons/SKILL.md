---
name: swiftcommons
description: Use when writing or reviewing Swift code in an app or package that depends on SwiftCommons (github.com/maniramezan/SwiftCommons). Maps common hand-rolled helpers (safe subscripts, blank-string checks, cached formatters, retry, debounce, async locks, loading state, config parsing, OSLog logging, signposts, SwiftData containers) to the SwiftCommons API, and lists the library's correctness pitfalls.
---

# SwiftCommons

SwiftCommons is a dependency-free Swift 6 library (iOS 17+, macOS 14+, Mac Catalyst 17+) of
Foundation extensions and app utilities. Before writing a helper, check this table. If the
project imports `SwiftCommons`, use the library API instead of reimplementing it.

## Reach for this instead of hand-rolling

| Need | Use |
|---|---|
| Bounds-checked element | `array[safe: i]` → `Element?`; `array[i, default: x]` |
| Bounds-clamped slice | `array[safe: 2..<10]` |
| Optional fallback with lazy default | `optional.ifNil(expensiveDefault())` |
| Trim / blank checks | `text.trimmed`, `text.isBlank`, `text.nilIfBlank` |
| Parse config text | `Bool(parsing:)` (true/false, 1/0, yes/no, on/off), `Int(parsing:)`, `Double(parsing:)` |
| Encode a boolean flag | `String(flag: true)` → `"1"` |
| Remote/env/plist config | `ConfigValue.environment()`, `ConfigValue.propertyList(_:)`, `.boolValue` / `.intValue` / `.doubleValue` |
| App version label | `Bundle.main.versionAndBuildNumber` → `"2.3.1 (142)"` |
| Stable ID from a string | `UUID.deterministicMD5(from:)` (not for security) |
| `Duration` → `TimeInterval` | `duration.timeInterval` |
| Fixed date pattern | `DateFormatter.formatter(.yyyyMMdd)` and the other `FormatType` cases |
| Localized date | `DateFormatter.formatter(template: "yMMMd", calendar: .current)` or `formatter(dateStyle:timeStyle:)` |
| "1 hour ago" | `date.relativeDescription()` |
| Numbers | `NumberFormatter.formatCurrency(_:currencyCode:)`, `.formatDecimal`, `.formatPercent`, `.formatOrdinal` |
| Any other cached `Formatter` | `FormatterCache.formatter(for: key) { makeFormatter() }` |
| `m:ss` / `h:mm:ss` | `DurationFormatter.format(seconds:)` |
| Calendar math | `calendar.startOfMonth(for:)`, `numberOfDays(in:year:)`, `dates(from:through:)`; era/leap-month-safe months via `CalendarArithmetic` + `MonthIdentifier` |
| Screen loading state | `LoadingState<Value>` with `state = await .load { try await fetch() }` |
| Serialize async work across awaits | `try await lock.withLock { … }` (`AsyncLock`) |
| Deduplicate concurrent identical requests | `try await singleFlight.value(for: key) { … }` (`SingleFlight<Key, Value>`) |
| Cap concurrency | `AsyncSemaphore(value: n).withPermit { … }` |
| Debounce | `await Debouncer(delay: .milliseconds(300)).run { … }` |
| Retry | `try await withRetry(attempts: 3, delay: .seconds(1)) { … }` |
| SwiftData container | `try ModelContainer.make(for: A.self, B.self, inMemory: isPreview)` |
| Measure hot paths | `SignpostRecorder(subsystem:category:).measure("name") { … }` |
| Offline sync | `SyncEngine` + `SyncResourceAdapter` — see the `swiftcommons-sync` skill |

## Logging conventions

- Create loggers with `Logger.forType(subsystem: "<AppName>", FeatureType.self)`.
- Log failures with `logger.error("What failed", error: error, context: "feature=… action=… id=…")`.
  The message, the context, and the error's type, domain and code are logged **public**. Only
  `localizedDescription` is private. So put IDs and state in `context`, never user-entered
  values or personal data.
- Use `infoPublic` / `debugPublic` for non-sensitive text and `infoPrivate` / `debugPrivate` for
  anything user-derived.
- Log before and after async operations; `traceEntry` / `traceExit` help when tracing control
  flow.

## Pitfalls

- **Cached formatters are shared per thread.** Treat the returned `DateFormatter` /
  `NumberFormatter` as read-only. Never set `dateFormat`, `locale`, etc. on it, and don't pass it
  across tasks or threads.
- **Numeric `FormatType` patterns ignore the locale.** `yyyyMMdd`, `MMddyyyy`, `ddMMyyyy`,
  `ddMMyyyyDotted`, `HHmm`, `HHmmss` and `yyyyMMddHHmm` always render Gregorian with ASCII digits
  (`en_US_POSIX`), which suits storage and APIs. For dates shown to users, use a template or style
  formatter.
- **`AsyncLock` isn't reentrant.** Calling `withLock` inside its own critical section deadlocks.
  `unlock()` is actor-isolated, so `defer { lock.unlock() }` doesn't compile; use `withLock`.
- **`Debouncer.run` must be awaited.** From synchronous code, wrapping it in `Task { await … }`
  can reorder calls.
- **`LoadingState.load` maps cancellation to `.idle`, not `.failed`.** `LoadingError(from:)`
  always shows a generic message, so construct `LoadingError(message:isRetryable:requiresSignIn:)`
  yourself when the user needs a specific message.
- **`URL` conforms to `ExpressibleByStringLiteral`.** Only use literals for known-good
  constants; an invalid literal is a runtime `preconditionFailure`.
- **CSV is opt-in.** Enable the `CSV` package trait to get `CSV.parseRows` /
  `CSV.serializeRows`.
- **`Locale.identifier(language:country:)` uses a curated subset.** The `Language` and `Country`
  enums don't cover every ISO code.

## Testing

For fake clocks, `LoadingState` assertions, and SwiftData or sync fixtures, see the
`swiftcommons-testing` skill.

Full API docs: https://maniramezan.github.io/SwiftCommons/documentation/swiftcommons
