//
//  DateFormatter+Extensions.swift
//  manman.core
//
//  Created by Mani Ramezan on 10/22/17.
//  Copyright © 2017 Mani Ramezan. All rights reserved.
//

import Foundation

extension DateFormatter {
	
	public enum FormatType: String {
		case MMMMddyyyy = "MMMM dd, yyyy"
		case MMMMdd = "MMMM dd"
		case MMddyyyy = "MM/dd/yyyy"
	}
	
	private static var _cacheDateFormatters: [FormatType: DateFormatter]!
	private static var cacheDateFormatters: [FormatType: DateFormatter] {
		get {
			if _cacheDateFormatters == nil {
				_cacheDateFormatters = [FormatType: DateFormatter]()
			}
			
			return _cacheDateFormatters
		}
	}
	
    public static func formatter(_ formatterType: FormatType,
                                 locale: Locale = Locale.current,
                                 timeZone: TimeZone = TimeZone.current)
        -> DateFormatter
    {
		if let dateFormatter = cacheDateFormatters[formatterType] {
			return dateFormatter;
		}
		
		let dateFormatter = DateFormatter()
		dateFormatter.timeZone = timeZone
		dateFormatter.locale = locale
		dateFormatter.dateFormat = formatterType.rawValue
		_cacheDateFormatters[formatterType] = dateFormatter
		
		return dateFormatter
	}
}
