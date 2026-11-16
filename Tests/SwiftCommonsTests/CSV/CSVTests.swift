#if CSV
import Testing

@testable import SwiftCommons

@Suite("CSV")
struct CSVTests {
    @Test
    func parseRowsHandlesSimpleCSV() {
        let rows = CSV.parseRows("Date,Habit,Value\n2026-01-01,Sleep,8")

        #expect(
            rows == [
                ["Date", "Habit", "Value"],
                ["2026-01-01", "Sleep", "8"],
            ])
    }

    @Test
    func parseRowsHandlesQuotedFieldsAndEscapedQuotes() {
        let rows = CSV.parseRows("\"Habit\",\"Note\"\n\"Sleep\",\"Said \"\"good night\"\"\"")

        #expect(
            rows == [
                ["Habit", "Note"],
                ["Sleep", "Said \"good night\""],
            ])
    }

    @Test
    func parseRowsHandlesQuotedNewlinesAndCRLF() {
        let rows = CSV.parseRows("\"Habit\",\"Note\"\r\n\"Sleep\",\"line 1\nline 2\"")

        #expect(
            rows == [
                ["Habit", "Note"],
                ["Sleep", "line 1\nline 2"],
            ])
    }

    @Test
    func parseRowsOmitsEmptyRows() {
        let rows = CSV.parseRows("A,B\n\n,\nC,D")

        #expect(
            rows == [
                ["A", "B"],
                ["C", "D"],
            ])
    }

    @Test
    func serializeRowsQuotesAndEscapesFields() {
        let csv = CSV.serializeRows([
            ["Habit", "Note"],
            ["Sleep", "Said \"good night\""],
        ])

        #expect(csv == "\"Habit\",\"Note\"\n\"Sleep\",\"Said \"\"good night\"\"\"")
    }

    @Test
    func serializeRowsRoundTripsThroughParser() {
        let rows = [
            ["Date", "Habit", "Value"],
            ["2026-01-01", "Sleep", "8"],
            ["2026-01-02", "Water", "1,250"],
        ]

        #expect(CSV.parseRows(CSV.serializeRows(rows)) == rows)
    }

    // MARK: Delimiters

    @Test
    func parseRowsHonorsACustomDelimiter() {
        #expect(
            CSV.parseRows("a;b;c\n1;2,5;3", delimiter: .semicolon) == [
                ["a", "b", "c"], ["1", "2,5", "3"],
            ])
        #expect(CSV.parseRows("a\tb\n1\t2", delimiter: .tab) == [["a", "b"], ["1", "2"]])
        #expect(CSV.parseRows("\"a|b\"|c", delimiter: .pipe) == [["a|b", "c"]])
    }

    @Test
    func delimiterRejectsQuotesLineBreaksAndNonASCII() {
        #expect(CSV.Delimiter("\"") == nil)
        #expect(CSV.Delimiter("\n") == nil)
        #expect(CSV.Delimiter("\r") == nil)
        #expect(CSV.Delimiter("\r\n") == nil)
        #expect(CSV.Delimiter("é") == nil)
        #expect(CSV.Delimiter("~") != nil)
        #expect(CSV.Delimiter(",") == .comma)
    }

    @Test
    func serializeRowsUsesTheDelimiterAndRoundTrips() throws {
        let rows = [["a", "b;c"], ["1", "2"]]
        let csv = CSV.serializeRows(rows, delimiter: .semicolon)

        #expect(csv == "\"a\";\"b;c\"\n\"1\";\"2\"")
        #expect(CSV.parseRows(csv, delimiter: .semicolon) == rows)
    }

    // MARK: Byte-level parsing

    @Test
    func parseRowsHandlesNonASCIIContent() {
        let rows = CSV.parseRows("名前,メモ\n\"héllo, wörld\",🙂\n")

        #expect(rows == [["名前", "メモ"], ["héllo, wörld", "🙂"]])
    }

    @Test
    func parseRowsHandlesBareCarriageReturnAndSkipsAByteOrderMark() {
        #expect(CSV.parseRows("a,b\rc,d") == [["a", "b"], ["c", "d"]])
        #expect(CSV.parseRows("\u{FEFF}name,age\nAda,36") == [["name", "age"], ["Ada", "36"]])
    }

    @Test
    func parseRowsKeepsAnUnterminatedFinalRowAndQuote() {
        #expect(CSV.parseRows("a,b\nc,d") == [["a", "b"], ["c", "d"]])
        #expect(CSV.parseRows("a,\"b\nc") == [["a", "b\nc"]])
        #expect(CSV.parseRows("") == [])
        #expect(CSV.parseRows("\n\r\n") == [])
    }

    /// The previous `Character`-walking parser, kept as the reference the byte-level parser must
    /// match on inputs whose only line breaks are `\n`, `\r`, and `\r\n`.
    private func referenceParseRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = csv.startIndex
        func appendIfNotEmpty() {
            if !currentRow.allSatisfy(\.isEmpty) { rows.append(currentRow) }
        }
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
                appendIfNotEmpty()
                currentRow = []
                index = csv.index(after: index)
            } else {
                currentField.append(character)
                index = csv.index(after: index)
            }
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            appendIfNotEmpty()
        }
        return rows
    }

    @Test
    func byteParserMatchesTheReferenceParserOnRandomInput() {
        var generator = SeededGenerator(seed: 0xC5F)
        let alphabet = ["a", "b", "1", " ", ",", "\"", "\"", "\n", "\r", "\r\n", "é", "名"]
        for _ in 0..<2_000 {
            let length = Int.random(in: 0...40, using: &generator)
            let input = (0..<length).map { _ in alphabet.randomElement(using: &generator) ?? "" }
                .joined()

            #expect(
                CSV.parseRows(input) == referenceParseRows(input),
                "input: \(input.debugDescription)")
        }
    }

    // MARK: Header-keyed records

    @Test
    func parseRecordsKeysEachRowByTheHeader() {
        let records = CSV.parseRecords("name,age\nAda,36\nGrace,85\n")

        #expect(records == [["name": "Ada", "age": "36"], ["name": "Grace", "age": "85"]])
    }

    @Test
    func parseRecordsHandlesShortLongAndDuplicateColumns() {
        let records = CSV.parseRecords("a,b,a\n1\n1,2,3,4\n5,6,7")

        #expect(records == [["a": "1"], ["a": "1", "b": "2"], ["a": "5", "b": "6"]])
    }

    @Test
    func parseRecordsWithOnlyAHeaderOrNothingIsEmpty() {
        #expect(CSV.parseRecords("a,b").isEmpty)
        #expect(CSV.parseRecords("").isEmpty)
    }

    @Test
    func parseRecordsHonorsTheDelimiterAndAByteOrderMark() {
        let records = CSV.parseRecords("\u{FEFF}name;note\nAda;\"x;y\"", delimiter: .semicolon)

        #expect(records == [["name": "Ada", "note": "x;y"]])
    }

    @Test
    func serializeRecordsWritesHeadersThenRowsInHeaderOrder() {
        let csv = CSV.serializeRecords(
            [["b": "2", "a": "1"], ["a": "3", "extra": "ignored"]], headers: ["a", "b"])

        #expect(csv == "\"a\",\"b\"\n\"1\",\"2\"\n\"3\",\"\"")
        #expect(
            CSV.parseRecords(csv) == [["a": "1", "b": "2"], ["a": "3", "b": ""]])
    }
}

/// A small deterministic generator so the randomized comparison is reproducible.
private struct SeededGenerator: RandomNumberGenerator {
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    private var state: UInt64
}
#endif
