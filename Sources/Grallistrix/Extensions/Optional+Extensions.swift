//
//  Optional+Extensions.swift
//  
//
//  Created by Mani Ramezan on 9/25/19.
//

import Foundation

extension Optional {
    @inlinable
    public func ifNil(_ defaultValue: Wrapped) -> Wrapped {
        if case .some(let wrapped) = self {
            return wrapped
        }
        
        return defaultValue
    }
}
