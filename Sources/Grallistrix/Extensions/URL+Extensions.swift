//
//  URL+Extensions.swift
//  manman.core
//
//  Created by Mani Ramezan on 10/15/18.
//  Copyright © 2018 Mani Ramezan. All rights reserved.
//

import Foundation

extension URL: ExpressibleByStringLiteral {
    public init(stringLiteral value: StaticString) {
        self = URL(string: "\(value)")!
    }
}
