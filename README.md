# SwiftCommons

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

DocC is included in `Sources/SwiftCommons/SwiftCommons.docc`.

Generate documentation locally:

```bash
swift package generate-documentation \
  --target SwiftCommons \
  --output-path /tmp/docc
```

## Contributing

See `CONTRIBUTING.md`.

## Code of Conduct

See `CODE_OF_CONDUCT.md`.

## Security

See `SECURITY.md`.

## License

See `LICENSE`.
