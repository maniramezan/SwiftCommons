# SwiftCommons

[![Swift Package Index](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/maniramezan/SwiftCommons/badge?type=swift-versions)](https://swiftpackageindex.com/maniramezan/SwiftCommons)
[![Swift Package Index](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/maniramezan/SwiftCommons/badge?type=platforms)](https://swiftpackageindex.com/maniramezan/SwiftCommons)
[![Build](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftCommons/build.yml?branch=main&label=build)](https://github.com/maniramezan/SwiftCommons/actions/workflows/build.yml)

Shared Swift utilities and helpers for reusable app code.

## Requirements

- Swift 6.2 toolchain
- macOS 13+, iOS 16+, Mac Catalyst 16+

## Installation

Add SwiftCommons as a Swift Package Manager dependency:

```swift
dependencies: [
    .package(url: "https://github.com/maniramezan/SwiftCommons.git", from: "0.1.0")
]
```

## Features

- **Collections & optionals** — safe and defaulted subscripts on `Array`, plus `Optional.ifNil(_:)`.
- **Numbers** — `FixedWidthInteger.digits` and locale-aware `NumberFormatter` helpers.
- **Dates & calendars** — `Calendar` date math and a thread-safe `DateFormatter` cache.
- **Localization** — `Language`/`Country` enums and `Locale` identifier helpers.
- **Logging** — OSLog `Logger` conveniences for categories, privacy, and context.

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

### Numbers

```swift
1234.digits                              // [4, 3, 2, 1]
NumberFormatter.formatYear(2024)         // "2024" (digits follow the locale)
```

### Dates & calendars

```swift
let formatter = DateFormatter.formatter(.MMMMddyyyy) // cached per thread
let dateString = formatter.string(from: Date())

let calendar = Calendar(identifier: .gregorian)
let monthStart = try calendar.startOfMonth(for: Date())
let days = try calendar.numberOfDays(in: 2, year: 2024) // 29
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

## Documentation

Full API documentation is published with DocC to GitHub Pages.

Generate documentation locally:

```bash
swift package generate-documentation \
  --target SwiftCommons \
  --output-path /tmp/docc
```
