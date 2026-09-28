import Foundation

extension String {
    private static let allowedEscapePunctuation = CharacterSet(charactersIn: "-._~")

    /// Encodes a raw URI component using RFC 3986's unreserved character set.
    ///
    /// Only ASCII letters, digits, `-`, `.`, `_`, and `~` remain unchanged.
    /// All other UTF-8 bytes become uppercase percent escapes. Spaces become
    /// `%20`, plus signs become `%2B`, and existing percent escapes are encoded
    /// again. Use on individual raw query names or values, not a complete URL.
    ///
    ///     "a&b=hello world".percentEncodedRFC3986 // "a%26b%3Dhello%20world"
    ///
    /// The original Unicode normalization is preserved byte for byte.
    public var percentEncodedRFC3986: String {
        let hex = Array("0123456789ABCDEF".utf8)
        var encoded: [UInt8] = []
        encoded.reserveCapacity(utf8.count)
        for byte in utf8 {
            let scalar = UnicodeScalar(byte)
            let character = Character(scalar)
            if character.isASCII
                && (character.isAlphanumeric || Self.allowedEscapePunctuation.contains(scalar))
            {
                encoded.append(byte)
            } else {
                encoded.append(UInt8(ascii: "%"))
                encoded.append(hex[Int(byte >> 4)])
                encoded.append(hex[Int(byte & 0x0F)])
            }
        }
        return String(decoding: encoded, as: UTF8.self)
    }
}
