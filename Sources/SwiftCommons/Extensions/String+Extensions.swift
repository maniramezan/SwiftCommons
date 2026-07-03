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
}
