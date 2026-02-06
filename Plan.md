# Plan

Use this file to track non-trivial work. Keep it short and updated as you go.

## Current Task

- None (completed public repo docs).

## Plan

1. Expand README with usage, docs, and contribution info.
2. Add CONTRIBUTING, CODE_OF_CONDUCT, and SECURITY docs.
3. Summarize changes and testing status.

## Progress Log

- 2026-02-06: Started DocC + CI documentation build work.
- 2026-02-06: Added DocC catalog and CI DocC generation step.
- 2026-02-06: Added SwiftFormat config, formatted code, and CI linting.
- 2026-02-06: Added swift-format dependency and build tool plugin.
- 2026-02-06: Added public repo docs (README, contributing, code of conduct, security).

## Decisions

- Generate DocC in CI with warnings as errors to enforce public API docs.
- Enforce SwiftFormat linting in CI with repo-configured settings.
- Run SwiftFormat lint as a build tool plugin using toolchain `xcrun` for compile-time enforcement.

## Testing

- Not run (CI will run build/test/doc generation).

## Open Questions

- None
