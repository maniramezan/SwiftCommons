# SwiftCommons

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Build](https://github.com/maniramezan/SwiftCommons/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/maniramezan/SwiftCommons/actions/workflows/build.yml)

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

## Usage

```swift
import SwiftCommons

let value = [1, 2, 3][safe: 10]
let fallback = ["a", "b"][5, default: "n/a"]

let formatter = DateFormatter.formatter(.MMMMddyyyy)
let dateString = formatter.string(from: Date())
```

## Documentation

DocC is generated from symbol graphs (no custom catalog).

Generate documentation locally:

```bash
swift package generate-documentation \
  --target SwiftCommons \
  --output-path /tmp/docc
```
