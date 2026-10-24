import Foundation

/// A numeric app version with major, minor, and patch components.
///
/// Missing components default to zero, so `"2.1"` compares equal to `"2.1.0"`.
/// Suffixes beginning with `-` or `+` are ignored: `"2.1.0-preview"` and
/// `"2.1.0+42"` both compare equal to `"2.1.0"`.
///
/// This type compares marketing versions. It does not implement semantic-version
/// prerelease precedence or validate the ignored suffix.
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// The major version component.
    public let major: Int
    /// The minor version component, defaulting to zero when omitted.
    public let minor: Int
    /// The patch version component, defaulting to zero when omitted.
    public let patch: Int

    /// Parses one to three nonnegative, ASCII decimal components separated by periods.
    ///
    /// Leading and trailing whitespace is trimmed. Empty components, signs,
    /// nonnumeric components, more than three components, and integer overflow
    /// return `nil`. Leading zeros are accepted and normalized.
    ///
    /// - Parameter string: An app version such as `"2.1.0"` or `"2.1-preview"`.
    public init?(string: String) {
        let core = string.trimmed.prefix { $0 != "-" && $0 != "+" }
        let components = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(components.count) else { return nil }

        var numbers: [Int] = []
        for component in components {
            guard component.utf8.allSatisfy({ (48...57).contains($0) }),
                let number = Int(component)
            else {
                return nil
            }
            numbers.append(number)
        }
        major = numbers[0]
        minor = numbers.count > 1 ? numbers[1] : 0
        patch = numbers.count > 2 ? numbers[2] : 0
    }

    /// The normalized `major.minor.patch` representation.
    public var description: String { "\(major).\(minor).\(patch)" }

    /// Compares major, minor, and patch components numerically, in that order.
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
