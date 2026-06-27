import Foundation

extension FixedWidthInteger {
    /// Breaks the number into its base-10 digits, least-significant first.
    ///
    /// The result lists digits in reverse order: index `0` holds the lowest-order
    /// digit and the last index holds the highest-order digit.
    ///
    ///     let num = 1234
    ///     print(num.digits) // [4, 3, 2, 1]
    ///
    /// For negative values each returned digit is negative, mirroring the sign of
    /// the number. The computation operates on `self` directly, so it is safe for
    /// the full range of any `FixedWidthInteger` (including `Int.min` and large
    /// unsigned values that do not fit in `Int`).
    ///
    ///     print((-1234).digits) // [-4, -3, -2, -1]
    ///
    public var digits: [Int] {
        guard self != 0 else { return [0] }

        var remaining = self
        var result: [Int] = []
        while remaining != 0 {
            let (quotient, remainder) = remaining.quotientAndRemainder(dividingBy: 10)
            result.append(Int(remainder))
            remaining = quotient
        }
        return result
    }
}
