//
//  FixedWidthInteger+Extensions.swift
//  
//
//  Created by Mani Ramezan on 9/8/19.
//

import Foundation

extension FixedWidthInteger {
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
