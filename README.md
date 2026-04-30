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
