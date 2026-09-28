extension Character {
    /// Whether this character is a Unicode letter or number.
    ///
    /// Equivalent to `isLetter || isNumber`, including non-ASCII letters,
    /// numeric characters such as fractions, and the standard library's
    /// handling of extended grapheme clusters. Punctuation is excluded.
    /// For ASCII-only validation, also require `isASCII`.
    @inlinable
    public var isAlphanumeric: Bool {
        isLetter || isNumber
    }
}
