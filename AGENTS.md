# AGENTS.md

Agent guidance for this repository.

Start here:
- Read `CLAUDE.md` first. It contains the shared project overview, build/test commands, structure, and key API patterns.

## Working Agreement

- Keep changes minimal and focused; prefer extending existing patterns over introducing new abstractions.
- Maintain Swift 6 language mode and platform minimums; avoid new dependencies unless explicitly requested.
- Public APIs should include doc comments and follow existing naming and formatting.
- Update or add tests in `Tests/SwiftCommonsTests` for any behavior changes.

## Code Style Notes

- 4-space indentation and clear, concise documentation comments.
- Small utility helpers often use `@inlinable`.
- Date and number formatting utilities should respect thread-safety constraints and existing caching patterns.

## Common Paths

- Sources: `Sources/SwiftCommons/`
- Tests: `Tests/SwiftCommonsTests/`

## Planning

- Use `Plan.md` for task planning and progress tracking when the work is non-trivial.
