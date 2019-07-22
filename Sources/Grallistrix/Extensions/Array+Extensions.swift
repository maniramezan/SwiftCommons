//
//  Array+Extensions.swift
//  
//
//  Created by Mani Ramezan on 9/8/19.
//

import Foundation

extension Array {
    @inlinable
    public subscript(index: Index, default defaultValue: @autoclosure () -> Element) -> Element {
        guard
            index >= 0,
            index < endIndex
        else {
            return defaultValue()
        }

        return self[index]
    }
    
    @inlinable
    public subscript(safe index: Index) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }

        return self[index]
    }
    
    @inlinable
    public subscript(bounds: Range<Index>, default defaultValue: @autoclosure () -> Element) -> Self.SubSequence {
        precondition(bounds.lowerBound >= 0)
        
        let newBounds = bounds.clamped(to: indices)
        return self[newBounds] + Array(repeating: defaultValue(), count: bounds.count - newBounds.count)
    }
    
    @inlinable
    public subscript(safe bounds: Range<Index>) -> Self.SubSequence {
        return self[bounds.clamped(to: indices)]
    }
    
    @inlinable
    public subscript(bounds: ClosedRange<Index>, default defaultValue: @autoclosure () -> Element) -> Self.SubSequence {
        self[Range(bounds), default: defaultValue()]
    }
    
    @inlinable
    public subscript(safe bounds: ClosedRange<Index>) -> Self.SubSequence {
        self[safe: Range(bounds)]
    }
}
