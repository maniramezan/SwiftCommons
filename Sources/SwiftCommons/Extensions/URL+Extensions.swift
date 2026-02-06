import Foundation

extension URL: @retroactive ExpressibleByStringLiteral {
    /// Initialize URL instance from a valid url in string format. CAUTIOUS: It causes runtime crashes if the string is invalid.
    /// - Parameter value: Valid URL in valid format, otherwise it crashes on runtime.
    /// - Precondition: Literal string should be a valid URL
    public init(stringLiteral value: StaticString) {
        guard let url = URL(string: "\(value)") else {
            preconditionFailure("Invalid URL literal: \(value)")
        }
        self = url
    }
}
