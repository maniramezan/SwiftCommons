//
//  Calendar+Extensions.swift
//  manman.core
//
//  Created by Mani Ramezan on 10/22/17.
//  Copyright © 2017 Mani Ramezan. All rights reserved.
//

import Foundation

extension Calendar {
	public static func calender(name: String) -> Calendar {
        let calendarIdentifier = Calendar.Identifier(string: name)
		
		return Calendar(identifier: calendarIdentifier)
	}
}

extension Calendar.Identifier {
    public init(string: String) {
        switch string.lowercased() {
        case "persian":
            self = .persian
        case "gregorian":
            self = .gregorian
        case "islamic":
            self = .islamic
        default:
            fatalError("Calendar type is not supported.")
        }
    }
}

extension Calendar.Identifier: CustomStringConvertible {
    public var description: String {
        switch self {
        case .persian:
            return "Persian"
        case .gregorian:
            return "Gregorian"
        default:
            return "\(self)".capitalized
        }
    }
}

extension Calendar.Identifier: Identifiable {
    public var id: Int {
        return hashValue
    }
}
