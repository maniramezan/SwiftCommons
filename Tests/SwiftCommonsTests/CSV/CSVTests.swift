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
    }
#endif
