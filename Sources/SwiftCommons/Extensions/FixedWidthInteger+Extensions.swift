import Foundation

extension FixedWidthInteger {
    /// Breaks the number to base10 digits representing the number. Result contains all digits in reverse, 0 index has the lowest degree and last index has the highest
    ///
    ///     let num = 1234
    ///     print(num.digits) // [4, 3, 2, 1]
    ///
    public var digits: [Int] {
        let upperBound = Int(ceil(log10(Double(self))))
        var num = Int(self)
        var digits = Array(repeating: 0, count: upperBound)
        for i in (0..<upperBound) {
            digits[i] = num.quotientAndRemainder(dividingBy: 10).remainder
            num /= 10
        }
        return digits
    }
}
