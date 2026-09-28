import Foundation

extension String {

    /// The string with leading and trailing whitespace and newlines removed.
    ///
    ///     "  hello \n".trimmed // "hello"
    @inlinable
    public var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `true` if the string is empty or contains only whitespace and newlines.
    ///
    ///     "   ".isBlank  // true
    ///     "hi".isBlank   // false
    @inlinable
    public var isBlank: Bool {
        trimmed.isEmpty
    }

    /// The trimmed string, or `nil` if it is blank.
    ///
    /// Useful for normalizing optional user input or decoded values where an
    /// empty or whitespace-only string should be treated as absent.
    ///
    ///     "  ".nilIfBlank    // nil
    ///     " hi ".nilIfBlank  // "hi"
    @inlinable
    public var nilIfBlank: String? {
        isBlank ? nil : trimmed
    }

    /// Returns a copy with all leading occurrences of `character` removed.
    ///
    ///     "///users/".trimmingLeading("/") // "users/"
    ///
    /// Compares whole Swift characters, including extended grapheme clusters.
    /// - Parameter character: The character to remove from the start.
    /// - Returns: The remaining string, or an empty string if every character matched.
    @inlinable
    public func trimmingLeading(_ character: Character) -> String {
        String(drop(while: { $0 == character }))
    }

    /// Returns a copy with all trailing occurrences of `character` removed.
    ///
    ///     "/users///".trimmingTrailing("/") // "/users"
    ///
    /// Compares whole Swift characters, including extended grapheme clusters.
    /// - Parameter character: The character to remove from the end.
    /// - Returns: The remaining string, or an empty string if every character matched.
    @inlinable
    public func trimmingTrailing(_ character: Character) -> String {
        var end = endIndex
        while end > startIndex {
            let previous = index(before: end)
            guard self[previous] == character else { break }
            end = previous
        }
        return String(self[..<end])
    }

    /// Prepends `character` unless it is already the first character.
    ///
    ///     "users".ensuringStarts(with: "/") // "/users"
    ///
    /// An empty string becomes the character. Existing repeated prefixes are
    /// preserved; use ``trimmingLeading(_:)`` first to collapse repetitions.
    /// - Parameter character: The character to add when absent.
    /// - Returns: The original string or a copy with the character prepended.
    @inlinable
    public func ensuringStarts(with character: Character) -> String {
        first == character ? self : String(character) + self
    }
}
