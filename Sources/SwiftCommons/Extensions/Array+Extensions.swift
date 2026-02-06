import Foundation

extension Array {

    /// Try to access array at the given index. If exists, it returns the element at the index. Otherwise, nil.
    ///
    ///     let arr = ["a", "b", "c"]
    ///     print(arr[1, default: "d"]) // "b"
    ///     print(arr[3, default: "d"]) // "d"
    ///
    /// - Parameters:
    ///   - index: Index of needed element.
    ///   - defaultValue: Default value to use if the index is out of bounds.
    /// - Returns: Element at given index if exists. Otherwise, the result of given default value.
    @inlinable
    public subscript(_ index: Index, default defaultValue: @autoclosure () -> Element) -> Element {
        self[safe: index] ?? defaultValue()
    }

    /// Try to access array at the given index. If exists, it returns the element at the index. Otherwise, nil.
    ///
    ///     let arr = ["a", "b", "c"]
    ///     print(arr[safe: 1]) // Optional("b")
    ///     print(arr[safe: 3]) // nil
    ///
    /// - Parameter index: Index of needed element.
    /// - Returns: Element at given index if exists. Otherwise, nil.
    @inlinable
    public subscript(safe index: Index) -> Element? {
        guard startIndex..<endIndex ~= index else {
            return nil
        }

        return self[index]
    }

    /// Access a subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    /// - Parameter range: Range of indices.
    /// - Parameter defaultValue: Default value to be used if the range is out of bounds.
    /// - Returns: A subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    /// - Precondition: `range.lowerBound` to be a valid index ≥ 0.
    @inlinable
    public subscript(range: Range<Index>, default defaultValue: @autoclosure () -> Element)
        -> Self.SubSequence
    {
        precondition(range.lowerBound >= 0)

        let newRange = range.clamped(to: indices)
        return self[newRange]
            + Array(repeating: defaultValue(), count: range.count - newRange.count)
    }

    /// Access a subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    /// - Parameter range: Range of indices.
    /// - Returns: A subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    @inlinable
    public subscript(safe range: Range<Index>) -> Self.SubSequence {
        return self[range.clamped(to: indices)]
    }

    /// Access a subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    /// - Parameter range: Range of indices.
    /// - Parameter defaultValue: Default value to be used if the range is out of bounds.
    /// - Returns: A subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    @inlinable
    public subscript(range: ClosedRange<Index>, default defaultValue: @autoclosure () -> Element)
        -> Self.SubSequence
    {
        self[Range(range), default: defaultValue()]
    }

    /// Access a subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    /// - Parameter range: Range of indices.
    /// - Returns: A subsequence of the array with the given range. If the range is out of bounds, the missing elements will be filled with the default value.
    @inlinable
    public subscript(safe range: ClosedRange<Index>) -> Self.SubSequence {
        self[safe: Range(range)]
    }
}
