# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftCommons is a Swift Package Manager library providing Foundation extensions and utilities. The package uses Swift 6 language mode and supports macOS 11+, iOS 16+, and Mac Catalyst 16+.

## Building and Testing

```bash
# Build the package
swift build

# Run all tests
swift test

# Build with verbose output
swift build -v
```

**Important:** If using Swift development snapshots (6.3-dev), `swift test` may fail with linker errors (`ld: unknown option: -no_warn_duplicate_libraries`). This is a known toolchain bug. Tests will work correctly when using stable Swift releases.

## Package Structure

The library is organized by functionality:

- **Extensions/** - Foundation type extensions (Array, Optional, URL, FixedWidthInteger, Locale, NumberFormatter)
- **Dates/** - Date/time utilities (Calendar, DateFormatter with cached formatters)
- **Logging/** - OSLog Logger extensions with SwiftCommons subsystem

## Code Patterns

### Safe Array Access
Extensions provide safe subscripting with optional unwrapping and default values:
```swift
arr[safe: index]           // Returns Optional<Element>
arr[index, default: value] // Returns Element with fallback
arr[safe: range]           // Safe range access
```

### Cached Formatters
DateFormatter uses a static cache to avoid expensive formatter creation:
```swift
DateFormatter.formatter(.MMMMddyyyy, locale: .current, timeZone: .current)
```

### Logger Integration
Standardized logging using OSLog with SwiftCommons subsystem:
```swift
Logger.swiftCommonsLogger(category: "MyCategory")
Logger.swiftCommonsLogger(for: MyType.self)
```

## Swift 6 Configuration

Package.swift uses package-level `swiftLanguageModes: [.v6]` instead of per-target `swiftSettings`. This is the recommended approach for Swift 6 packages.
