#if CSV
    import Foundation

    /// Lightweight CSV parsing and serialization helpers.
    public enum CSV {
        /// Parses CSV content into rows and fields.
        ///
        /// Handles comma separators, CRLF/LF line endings, quoted fields, escaped quotes, and quoted
        /// newlines. Empty rows are omitted.
        public static func parseRows(_ csv: String) -> [[String]] {
            var rows: [[String]] = []
            var currentRow: [String] = []
            var currentField = ""
            var insideQuotes = false
            var index = csv.startIndex

            while index < csv.endIndex {
                let character = csv[index]

                if insideQuotes {
                    if character == "\"" {
                        let next = csv.index(after: index)
                        if next < csv.endIndex, csv[next] == "\"" {
                            currentField.append("\"")
                            index = csv.index(after: next)
                        } else {
                            insideQuotes = false
                            index = next
                        }
                    } else {
                        currentField.append(character)
                        index = csv.index(after: index)
                    }
                } else if character == "\"" {
                    insideQuotes = true
                    index = csv.index(after: index)
                } else if character == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    index = csv.index(after: index)
                } else if character.isNewline {
                    currentRow.append(currentField)
                    currentField = ""
                    appendRowIfNotEmpty(currentRow, to: &rows)
                    currentRow = []
                    index = csv.index(after: index)
                } else {
                    currentField.append(character)
                    index = csv.index(after: index)
                }
            }

            if !currentField.isEmpty || !currentRow.isEmpty {
                currentRow.append(currentField)
                appendRowIfNotEmpty(currentRow, to: &rows)
            }

            return rows
        }

        /// Serializes rows and fields to CSV content.
        ///
        /// Fields are always quoted for predictable round-tripping.
        public static func serializeRows(_ rows: [[String]]) -> String {
            rows.map { row in
                row.map { field in
                    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }.joined(separator: ",")
            }.joined(separator: "\n")
        }

        private static func appendRowIfNotEmpty(_ row: [String], to rows: inout [[String]]) {
            if !row.allSatisfy(\.isEmpty) {
                rows.append(row)
            }
        }
    }
#endif
