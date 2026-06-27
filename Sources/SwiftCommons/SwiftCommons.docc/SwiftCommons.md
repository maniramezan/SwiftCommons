# ``SwiftCommons``

Foundation extensions and small, dependency-free utilities for reusable app code.

## Overview

SwiftCommons is a lightweight Swift Package Manager library of Foundation
extensions and helpers used across Apple-platform apps. It has no external
runtime dependencies, builds in Swift 6 language mode, and targets macOS 13+,
iOS 16+, and Mac Catalyst 16+.

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
- **Numbers** — `FixedWidthInteger.digits` and locale-aware
  `NumberFormatter` helpers (`formatYear`, `formatDay`).
- **Dates & calendars** — `Calendar` date math (start of week/month, month
  symbols, month/year arithmetic) and a thread-safe `DateFormatter.formatter(_:)`
  cache.
- **Localization** — the ``Language`` and ``Country`` enums plus `Locale`
  identifier helpers (`Locale.identifier(language:country:)`,
  `Locale.Identifiers`, and `withNumberingSystemIdentifier(_:)`).
- **Logging** — OSLog `Logger` conveniences for category creation, privacy
  levels, and error/context logging.

Foundation, Swift standard library, and OSLog extensions are listed under
**Extensions** below.

## Topics

### Localization

- ``Language``
- ``Country``
