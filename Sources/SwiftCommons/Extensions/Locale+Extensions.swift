import Foundation

extension Locale {
    /// Common locale identifiers used by SwiftCommons.
    public enum Identifier {
        /// Persian (Iran) locale identifier.
        public static let faIR = "fa_IR"
        /// English (United States) locale identifier.
        public static let enUS = "en_US"
    }

    /// Creates a locale that matches the provided calendar identifier.
    /// - Parameter calendarIdentifier: The calendar system to derive the locale from.
    public init(calendarIdentifier: Calendar.Identifier) {
        let identifier: String
        switch calendarIdentifier {
        case .gregorian:
            identifier = Identifier.enUS
        case .persian:
            identifier = Identifier.faIR
        default:
            identifier = Identifier.enUS
        }
        self.init(identifier: identifier)
    }

    /// Unicode numbering system identifiers for locale customization.
    public enum NumberingSystemIdentifier: String {
        /// Latin digits (0-9).
        case latin = "latn"
        /// Arabic-Indic digits.
        case arab = "arab"
        /// Eastern Arabic-Indic digits.
        case arabExtended = "arabext"
    }

    /// Returns a copy of the locale using the specified numbering system.
    /// - Parameter system: The numbering system identifier to apply.
    public func withNumberingSystemIdentifier(_ system: NumberingSystemIdentifier) -> Locale {
        Locale(identifier: "\(identifier)-u-nu-\(system.rawValue)")
    }
}
