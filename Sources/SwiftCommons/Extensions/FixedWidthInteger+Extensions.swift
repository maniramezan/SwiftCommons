import Foundation

extension FixedWidthInteger {
    /// Breaks the number to base10 digits representing the number. Result contains all digits in reverse, 0 index has the lowest degree and last index has the highest
    ///
    ///     let num = 1234
    ///     print(num.digits) // [4, 3, 2, 1]
    ///
    public var digits: [Int] {
        var num = Int(self)
        guard num != 0 else { return [0] }

        let isNegative = num < 0
        if isNegative { num = -num }

        var result: [Int] = []
        while num > 0 {
            let (quotient, remainder) = num.quotientAndRemainder(dividingBy: 10)
            result.append(isNegative ? -remainder : remainder)
            num = quotient
        }
        return result
    }
}
