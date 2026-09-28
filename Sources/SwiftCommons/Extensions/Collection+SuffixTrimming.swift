import RegexBuilder

extension BidirectionalCollection {
    /// Returns the subsequence after removing trailing elements that satisfy `predicate`.
    ///
    /// Evaluates the predicate from the end, stopping at the first nonmatching element.
    /// - Parameter predicate: Whether a trailing element should be removed.
    /// - Returns: The remaining subsequence.
    /// - Throws: Any error thrown by `predicate`.
    @inlinable
    public func trimmingSuffix(while predicate: (Element) throws -> Bool) rethrows -> SubSequence {
        var end = endIndex
        while end != startIndex {
            let previous = index(before: end)
            guard try predicate(self[previous]) else { break }
            end = previous
        }
        return self[..<end]
    }
}

extension BidirectionalCollection where Element: Equatable {
    /// Returns the subsequence after removing one matching suffix.
    ///
    /// An empty or nonmatching suffix leaves the collection unchanged.
    /// - Parameter suffix: The sequence to match at the end.
    /// - Returns: The remaining subsequence.
    @inlinable
    public func trimmingSuffix<Suffix: Sequence>(_ suffix: Suffix) -> SubSequence
    where Suffix.Element == Element {
        var end = endIndex
        for element in Array(suffix).reversed() {
            guard end != startIndex else { return self[...] }
            let previous = index(before: end)
            guard self[previous] == element else { return self[...] }
            end = previous
        }
        return self[..<end]
    }
}

extension BidirectionalCollection where Self == SubSequence {
    /// Removes trailing elements that satisfy `predicate` in place.
    /// - Parameter predicate: Whether a trailing element should be removed.
    /// - Throws: Any error thrown by `predicate`; the collection remains unchanged on failure.
    @inlinable
    public mutating func trimSuffix(while predicate: (Element) throws -> Bool) rethrows {
        self = try trimmingSuffix(while: predicate)
    }

    /// Removes one matching suffix in place; an empty or nonmatching suffix has no effect.
    /// - Parameter suffix: The sequence to match at the end.
    @inlinable
    public mutating func trimSuffix<Suffix: Sequence>(_ suffix: Suffix)
    where Element: Equatable, Suffix.Element == Element {
        self = trimmingSuffix(suffix)
    }
}

extension RangeReplaceableCollection where Self: BidirectionalCollection {
    /// Removes trailing elements that satisfy `predicate` in place.
    /// - Parameter predicate: Whether a trailing element should be removed.
    /// - Throws: Any error thrown by `predicate`; the collection remains unchanged on failure.
    @_disfavoredOverload
    @inlinable
    public mutating func trimSuffix(while predicate: (Element) throws -> Bool) rethrows {
        let end = try trimmingSuffix(while: predicate).endIndex
        removeSubrange(end..<endIndex)
    }

    /// Removes one matching suffix in place; an empty or nonmatching suffix has no effect.
    /// - Parameter suffix: The sequence to match at the end.
    @_disfavoredOverload
    @inlinable
    public mutating func trimSuffix<Suffix: Sequence>(_ suffix: Suffix)
    where Element: Equatable, Suffix.Element == Element {
        let end = trimmingSuffix(suffix).endIndex
        removeSubrange(end..<endIndex)
    }
}

extension BidirectionalCollection where SubSequence == Substring {
    /// Returns the text before the first regex match that reaches the end of the text.
    ///
    /// The regex is anchored to the end of the subject. A nonmatch or matching error
    /// leaves the text unchanged, mirroring `trimmingPrefix(_:)`'s regex behavior.
    /// - Parameter regex: The pattern to match at the end.
    /// - Returns: The remaining substring.
    @_disfavoredOverload
    public func trimmingSuffix(_ regex: some RegexComponent) -> Substring {
        let anchored = Regex {
            regex
            Anchor.endOfSubject
        }
        guard let match = try? anchored.firstMatch(in: self[...]) else { return self[...] }
        return self[..<match.range.lowerBound]
    }
}

extension RangeReplaceableCollection where Self: BidirectionalCollection, SubSequence == Substring {
    /// Removes the first regex match that reaches the end of the text in place.
    ///
    /// A nonmatch or matching error leaves the text unchanged.
    /// - Parameter regex: The pattern to match at the end.
    @_disfavoredOverload
    public mutating func trimSuffix(_ regex: some RegexComponent) {
        let end = trimmingSuffix(regex).endIndex
        removeSubrange(end..<endIndex)
    }
}
