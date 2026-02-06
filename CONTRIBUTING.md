# Contributing to SwiftCommons

Thanks for contributing! This repository aims to keep changes minimal and focused.

## Requirements

- Swift 6.2 toolchain (includes `swift-format` on PATH)

## Build and Test

```bash
swift build
swift test
```

## Formatting

SwiftCommons uses Apple’s `swift-format` with a repo config file.

Format the codebase:

```bash
xcrun swift-format format --configuration .swift-format --in-place --recursive Sources Tests
```

Linting runs as a SwiftPM build tool plugin and in CI. If you see a plugin
prompt, allow the plugin to run.

## Documentation

Public API changes should include DocC or doc comments where appropriate.
DocC content lives in `Sources/SwiftCommons/SwiftCommons.docc`.

## Submitting Changes

- Keep changes focused and consistent with existing patterns.
- Update or add tests under `Tests/SwiftCommonsTests` for behavior changes.
