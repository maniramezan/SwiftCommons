//
//  StringProtocol+CharacterDirection.swift
//  SwiftCommons
//

import Foundation

extension StringProtocol {
    /// The reading direction implied by the text itself, using the Unicode
    /// bidirectional algorithm's "first strong character" rule (UAX #9, P2–P3).
    ///
    /// The first letter from a right-to-left script (Hebrew, Arabic, Syriac,
    /// Thaana, N'Ko, Samaritan, Mandaic, and the RTL historic scripts) makes the
    /// text right-to-left; the first letter from any other script makes it
    /// left-to-right. Digits, punctuation, symbols, and whitespace are neutral
    /// and skipped.
    ///
    /// Use it when you only have the text. When you know the text's language,
    /// prefer `Locale.Language(identifier:).characterDirection`.
    ///
    /// ```swift
    /// "- [Ana] Hello".firstStrongCharacterDirection  // .leftToRight
    /// "12, مرحبا".firstStrongCharacterDirection       // .rightToLeft
    /// "123 ...".firstStrongCharacterDirection         // nil
    /// ```
    ///
    /// - Returns: `.leftToRight` or `.rightToLeft`, or `nil` when the text has
    ///   no letters.
    public var firstStrongCharacterDirection: Locale.LanguageDirection? {
        for scalar in unicodeScalars where scalar.properties.isAlphabetic {
            return scalar.isInRightToLeftScriptBlock ? .rightToLeft : .leftToRight
        }
        return nil
    }
}

extension Unicode.Scalar {
    /// Whether the scalar sits in a Unicode block assigned to a right-to-left
    /// script: Hebrew through Arabic Extended (U+0590–U+08FF), the Hebrew and
    /// Arabic presentation forms, the RTL historic scripts in the SMP
    /// (U+10800–U+10FFF), and Adlam / Arabic mathematical symbols
    /// (U+1E800–U+1EFFF).
    fileprivate var isInRightToLeftScriptBlock: Bool {
        switch value {
        case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x10800...0x10FFF,
            0x1E800...0x1EFFF:
            return true
        default:
            return false
        }
    }
}
