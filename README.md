# SwiftCommons

[![Swift Package Index](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/maniramezan/SwiftCommons/badge?type=swift-versions)](https://swiftpackageindex.com/maniramezan/SwiftCommons)
[![Swift Package Index](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/maniramezan/SwiftCommons/badge?type=platforms)](https://swiftpackageindex.com/maniramezan/SwiftCommons)
[![Build](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftCommons/build.yml?branch=main&label=build)](https://github.com/maniramezan/SwiftCommons/actions/workflows/build.yml)

Shared Swift utilities and helpers for reusable app code.

## Requirements

- Swift 6.2 toolchain
- macOS 14+, iOS 17+, Mac Catalyst 17+ (required by the SwiftData-backed APIs)

## Installation

Add SwiftCommons as a Swift Package Manager dependency:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftCommons.git", from: "0.3.0")
]
```

SwiftCommons ships two products:

- **`SwiftCommons`** — the main library. Add this to any target that uses the APIs below.
- **`SwiftCommonsTestSupport`** — test-only helpers (fake clock, `LoadingState` assertions,
  in-memory SwiftData context, sync test fixtures). Add this to your test targets only.

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "SwiftCommons", package: "SwiftCommons")
]),
.testTarget(name: "MyAppTests", dependencies: [
    "MyApp",
    .product(name: "SwiftCommons", package: "SwiftCommons"),
    .product(name: "SwiftCommonsTestSupport", package: "SwiftCommons"),
]),
```

CSV helpers are opt-in via the `CSV` package trait:

```swift
.package(url: "https://github.com/maniramezan/SwiftCommons.git", from: "0.3.0", traits: ["CSV"])
```

## Features

- **Extensions** — safe/defaulted `Array` subscripts, `Optional.ifNil(_:)`, `String` blank/trim
  helpers, the `StringParsable` protocol (`T(parsing:)` with a lenient `Bool` parser) and
  `String(flag:)` boolean-flag helpers, `Bundle` app-version accessors, `UUID` byte/deterministic
  helpers, `Duration.timeInterval`, `URL` string-literal support, and locale-aware
  `NumberFormatter`/`FixedWidthInteger` helpers.
- **Dates & calendars** — `Calendar` date math (start of week/month, inclusive date ranges, month
  arithmetic), a thread-safe `DateFormatter` cache, and `Date.relativeDescription(...)` for
  human-readable relative times ("1 hour ago").
- **Localization** — `Language`/`Country` enums and `Locale` identifier helpers.
- **Logging** — OSLog `Logger` conveniences for categories, privacy, and context.
- **Formatting** — `DurationFormatter` for compact `m:ss` / `h:mm:ss` durations.
- **State** — a generic `LoadingState` machine (`idle`/`loading`/`loaded`/`failed`) with a
  user-safe `LoadingError`, including a `LoadingState.load { ... }` helper for wrapping async work.
- **Configuration** — `ConfigValue`, a lenient `bool`/`string`/`int`/`double` coercion type, with
  loaders for `ProcessInfo.environment` and decoded property lists, plus a `ConfigValueType` tag and
  `ConfigValue(string:valueType:)` for decoding a textual value whose type is known separately.
- **Concurrency** — `AsyncLock` (FIFO mutex), `AsyncSemaphore` (counting semaphore), `Debouncer`,
  and `withRetry(...)` — all built on the injectable `SwiftCommonsClock` abstraction so consumers
  can substitute a fake clock in tests.
- **CSV** — lightweight CSV parsing/serialization (behind the `CSV` package trait).
- **Persistence** — `ModelContainer.make(for:inMemory:)`, a thin SwiftData bootstrap helper for
  apps, previews, and tests.
- **Sync** — a generic `SyncEngine` that drives offline, cross-device sync for SwiftData-backed
  resources through one contract-owning loop; resources plug in as `SyncResourceAdapter` values.

## Usage

### Collections & optionals

```swift
import SwiftCommons

let value = [1, 2, 3][safe: 10]          // nil — no crash
let fallback = ["a", "b"][5, default: "n/a"]  // "n/a"
let slice = [1, 2, 3][safe: 1..<10]      // [2, 3]

let name: String? = nil
let resolved = name.ifNil("Anonymous")   // "Anonymous"
```

### Strings, Bundle, and UUID

```swift
"  hi  ".trimmed        // "hi"
"   ".nilIfBlank        // nil

Bool(parsing: "yes")   // true — also accepts 1/0, on/off, true/false
Int(parsing: "42")     // 42 — T(parsing:) works for any StringParsable
String(flag: true)     // "1"

Bundle.main.versionAndBuildNumber  // "2.3.1 (142)"

UUID().bytes             // [UInt8], canonical byte order
```

### Numbers & currency

```swift
1234.digits                                          // [4, 3, 2, 1]
NumberFormatter.formatYear(2024)                      // "2024" (digits follow the locale)
NumberFormatter.formatCurrency(9.99, currencyCode: "USD") // "$9.99"
```

### Dates & calendars

```swift
let formatter = DateFormatter.formatter(.MMMMddyyyy) // cached per thread
let dateString = formatter.string(from: Date())

let calendar = Calendar(identifier: .gregorian)
let monthStart = try calendar.startOfMonth(for: Date())
let days = try calendar.numberOfDays(in: 2, year: 2024) // 29

Date().addingTimeInterval(-3600).relativeDescription() // "1 hour ago"
```

### Localization

```swift
let id = Locale.identifier(language: .french, country: .canada) // "fr-CA"
let preset = Locale.Identifiers.englishUS                        // "en-US"
let persian = Locale(identifier: "fa_IR").withNumberingSystemIdentifier(.arabExtended)
```

### Logging

```swift
let logger = Logger.swiftCommonsLogger(for: MyType.self)
logger.infoPublic("Started")
logger.error("Failed to load", error: error, context: "id=\(id)")
```

### State & configuration

```swift
var state: LoadingState<[Item]> = await .load { try await api.fetchItems() }
if let items = state.value { /* ... */ }
if let error = state.error { showError(error.message, retryable: error.isRetryable) }

let config = ConfigValue.environment()
let isDebug = config["DEBUG_MODE"]?.boolValue ?? false

// Decode a textual value when its type is known separately
ConfigValue(string: "yes", valueType: .bool)  // .bool(true)
ConfigValue(string: "7.5", valueType: .int)   // nil
```

### Concurrency

```swift
let data = try await withRetry(attempts: 3, delay: .seconds(1)) {
    try await fetchData()
}

let debouncer = Debouncer(delay: .milliseconds(300))
func searchFieldDidChange(_ query: String) {
    debouncer.run { await performSearch(query) }
}

let semaphore = AsyncSemaphore(value: 3) // cap concurrent requests
let response = try await semaphore.withPermit { try await urlSession.data(from: url) }
```

### Persistence (SwiftData)

```swift
let container = try ModelContainer.make(for: Item.self, Tag.self)
let previewContainer = try ModelContainer.make(for: Item.self, inMemory: true)
```

### Testing your own code

Add the `SwiftCommonsTestSupport` product to your test target to get:

```swift
import SwiftCommonsTestSupport

let clock = ManualSwiftCommonsClock()
let debouncer = Debouncer(delay: .seconds(1), clock: clock)
// ... trigger debounced work, then:
await clock.advance(by: .seconds(1)) // resumes the pending action deterministically

let context = try makeInMemoryModelContext(for: Item.self)

let state = await LoadingState.load { try await fetchItems() }
expectLoaded(state) // records a test failure if `state` isn't `.loaded`
```

## Documentation

Full API documentation is published with DocC to GitHub Pages.

Generate documentation locally:

```bash
swift package generate-documentation \
  --target SwiftCommons \
  --output-path /tmp/docc
```
