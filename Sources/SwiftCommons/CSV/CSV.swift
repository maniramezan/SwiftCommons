#if CSV
import Foundation

/// Lightweight CSV parsing and serialization helpers.
public enum CSV {
    /// The character that separates fields within a row.
    ///
    /// The delimiter must be a single ASCII character other than a quote or a line break, which
    /// lets the parser scan UTF-8 bytes directly. Use a preset, or ``init(_:)`` for another one.
    public struct Delimiter: Sendable, Hashable {
        /// A comma, the default.
        public static let comma = Delimiter(byte: UInt8(ascii: ","))
        /// A semicolon, common in locales that use a decimal comma.
        public static let semicolon = Delimiter(byte: UInt8(ascii: ";"))
        /// A tab (TSV).
        public static let tab = Delimiter(byte: UInt8(ascii: "\t"))
        /// A vertical bar.
        public static let pipe = Delimiter(byte: UInt8(ascii: "|"))

        /// Creates a delimiter from a character.
        ///
        /// - Parameter character: A single ASCII character that is not a quote (`"`), a carriage
        ///   return, or a line feed.
        /// - Returns: `nil` if `character` can't be used as a delimiter.
        public init?(_ character: Character) {
            guard let byte = character.asciiValue,
                byte != Delimiter.quote, byte != Delimiter.lineFeed,
                byte != Delimiter.carriageReturn
            else { return nil }
            self.byte = byte
        }

        fileprivate init(byte: UInt8) {
            self.byte = byte
        }

        fileprivate let byte: UInt8

        fileprivate static let quote = UInt8(ascii: "\"")
        fileprivate static let lineFeed = UInt8(ascii: "\n")
        fileprivate static let carriageReturn = UInt8(ascii: "\r")
    }

    /// Parses CSV content into rows and fields.
    ///
    /// Handles quoted fields, escaped quotes, quoted newlines, and LF, CRLF, or CR line endings.
    /// Empty rows are omitted, and a leading UTF-8 byte order mark is skipped. The text is scanned
    /// as UTF-8 bytes rather than `Character`s, so large inputs parse quickly; only `\n`, `\r`, and
    /// `\r\n` end a row (not Unicode line or paragraph separators).
    ///
    /// - Parameters:
    ///   - csv: The CSV text.
    ///   - delimiter: The field separator. Defaults to ``Delimiter/comma``.
    /// - Returns: The rows, each an array of its fields.
    public static func parseRows(_ csv: String, delimiter: Delimiter = .comma) -> [[String]] {
        var csv = csv
        return csv.withUTF8 { parse($0, delimiter: delimiter.byte) }
    }

    /// Parses CSV content whose first row is a header into one dictionary per data row.
    ///
    /// Each record maps a header name to that row's field in the same column. A row with fewer
    /// fields than the header leaves the missing names out of its dictionary, extra fields are
    /// ignored, and when a header name repeats the first column wins. Rows are parsed as in
    /// ``parseRows(_:delimiter:)``.
    ///
    /// - Parameters:
    ///   - csv: The CSV text, header row first.
    ///   - delimiter: The field separator. Defaults to ``Delimiter/comma``.
    /// - Returns: One dictionary per data row, or an empty array when there is no header.
    public static func parseRecords(
        _ csv: String, delimiter: Delimiter = .comma
    ) -> [[String: String]] {
        let rows = parseRows(csv, delimiter: delimiter)
        guard let header = rows.first else { return [] }
        return rows.dropFirst().map { row in
            var record: [String: String] = [:]
            for (name, field) in zip(header, row) where record[name] == nil {
                record[name] = field
            }
            return record
        }
    }

    /// Serializes rows and fields to CSV content.
    ///
    /// Fields are always quoted for predictable round-tripping.
    ///
    /// - Parameters:
    ///   - rows: The rows to write.
    ///   - delimiter: The field separator. Defaults to ``Delimiter/comma``.
    public static func serializeRows(_ rows: [[String]], delimiter: Delimiter = .comma) -> String {
        let separator = String(UnicodeScalar(delimiter.byte))
        return rows.map { row in
            row.map { field in
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }.joined(separator: separator)
        }.joined(separator: "\n")
    }

    /// Serializes records to CSV content, writing `headers` as the first row.
    ///
    /// Each record's fields are written in `headers` order; a missing key becomes an empty field,
    /// and keys not listed in `headers` are not written.
    ///
    /// - Parameters:
    ///   - records: The records to write.
    ///   - headers: The column names, in column order.
    ///   - delimiter: The field separator. Defaults to ``Delimiter/comma``.
    public static func serializeRecords(
        _ records: [[String: String]], headers: [String], delimiter: Delimiter = .comma
    ) -> String {
        serializeRows(
            [headers] + records.map { record in headers.map { record[$0] ?? "" } },
            delimiter: delimiter)
    }

    private static func parse(_ bytes: UnsafeBufferPointer<UInt8>, delimiter: UInt8) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var insideQuotes = false
        var index = 0
        let count = bytes.count

        // Skip a UTF-8 byte order mark.
        if count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            index = 3
        }

        func endField() {
            row.append(String(decoding: field, as: UTF8.self))
            field.removeAll(keepingCapacity: true)
        }

        func endRow() {
            endField()
            if !row.allSatisfy(\.isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < count {
            let byte = bytes[index]
            if insideQuotes {
                if byte == Delimiter.quote {
                    if index + 1 < count, bytes[index + 1] == Delimiter.quote {
                        field.append(Delimiter.quote)
                        index += 2
                    } else {
                        insideQuotes = false
                        index += 1
                    }
                } else {
                    field.append(byte)
                    index += 1
                }
            } else if byte == Delimiter.quote {
                insideQuotes = true
                index += 1
            } else if byte == delimiter {
                endField()
                index += 1
            } else if byte == Delimiter.lineFeed {
                endRow()
                index += 1
            } else if byte == Delimiter.carriageReturn {
                endRow()
                index += 1
                if index < count, bytes[index] == Delimiter.lineFeed {
                    index += 1
                }
            } else {
                field.append(byte)
                index += 1
            }
        }

        if !field.isEmpty || !row.isEmpty {
            endRow()
        }

        return rows
    }
}
#endif
