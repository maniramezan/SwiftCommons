import Foundation

extension DecodingError {
    /// A short, log-friendly description of the failure: its kind, the key or type involved,
    /// and a readable coding path.
    ///
    ///     keyNotFound 'id' at items[2].user
    ///     typeMismatch Int at items[2].user.age
    ///     valueNotFound String at items[0].name
    ///     dataCorrupted at createdAt
    ///     dataCorrupted at <root>
    ///
    /// Unlike `String(describing:)` or the context's `debugDescription`, the summary never
    /// includes decoded values (a `RawRepresentable` failure's `debugDescription`, for example,
    /// quotes the invalid raw value). Coding keys are included as-is, so a path through a
    /// dictionary with data-derived keys, such as `[String: User]` keyed by email, shows those
    /// keys.
    public var debugSummary: String {
        switch self {
        case .keyNotFound(let key, let context):
            return "keyNotFound '\(key.stringValue)' at \(Self.pathDescription(context.codingPath))"
        case .valueNotFound(let type, let context):
            return "valueNotFound \(type) at \(Self.pathDescription(context.codingPath))"
        case .typeMismatch(let type, let context):
            return "typeMismatch \(type) at \(Self.pathDescription(context.codingPath))"
        case .dataCorrupted(let context):
            return "dataCorrupted at \(Self.pathDescription(context.codingPath))"
        @unknown default:
            return "DecodingError"
        }
    }

    /// Renders a coding path as `items[2].user.id`: array indices become subscripts and an
    /// empty path becomes `<root>`.
    static func pathDescription(_ codingPath: [any CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        var description = ""
        for key in codingPath {
            if let index = Self.arrayIndex(of: key) {
                description += "[\(index)]"
            } else {
                if !description.isEmpty {
                    description += "."
                }
                description += key.stringValue
            }
        }
        return description
    }

    /// The index of an unkeyed-container key. Foundation's decoders name these `Index 2`; a
    /// `CodingKeys` enum with `Int` raw values also has an `intValue` but keeps its name.
    private static func arrayIndex(of key: any CodingKey) -> Int? {
        guard let index = key.intValue,
            key.stringValue == "Index \(index)" || key.stringValue == String(index)
        else { return nil }
        return index
    }
}
