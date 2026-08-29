import Foundation

/// A type that can be parsed from the loose textual forms that configuration files,
/// environment variables, and command-line arguments carry in practice.
///
/// Conformance is free for anything already `LosslessStringConvertible` (`Int`, `Double`,
/// `String`, …); `Bool` overrides it with a wider parser — see below. The uniform
/// `T(parsing:)` spelling lets a generic caller parse without special-casing `Bool`.
public protocol StringParsable {

    /// Parses a value from `text`, or returns `nil` when `text` is not a valid
    /// representation of `Self`.
    ///
    /// - Parameter text: The raw string to parse.
    init?(parsing text: String)
}

extension StringParsable where Self: LosslessStringConvertible {

    /// Default: defer to `LosslessStringConvertible`.
    public init?(parsing text: String) {
        self.init(text)
    }
}

extension Int: StringParsable {}
extension Double: StringParsable {}
extension String: StringParsable {}

extension Bool: StringParsable {

    /// Parses `true`/`false`, `1`/`0`, `yes`/`no`, `on`/`off` (case-insensitive, surrounding
    /// whitespace ignored).
    ///
    /// The standard library's `LosslessStringConvertible` conformance only accepts exactly
    /// `"true"` or `"false"`; config and environment sources use the `0`/`1` and `yes`/`no`
    /// spellings just as often.
    ///
    /// - Parameter text: The raw string to parse.
    public init?(parsing text: String) {
        switch text.trimmed.lowercased() {
        case "true", "1", "yes", "on":
            self = true
        case "false", "0", "no", "off":
            self = false
        default:
            return nil
        }
    }
}

// MARK: - Boolean flags

extension String {

    /// The canonical string form of a `true` boolean flag as environment variables and launch
    /// arguments carry it. Parse the other direction with `Bool(parsing:)`.
    public static let enabledFlag = "1"

    /// The canonical string form of a `false` boolean flag. See ``enabledFlag``.
    public static let disabledFlag = "0"

    /// `"1"` when `flag` is `true`, `"0"` when `false` — so a call site never types the
    /// literal.
    ///
    /// - Parameter flag: The boolean to encode.
    public init(flag: Bool) {
        self = flag ? .enabledFlag : .disabledFlag
    }
}
