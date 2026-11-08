import Foundation
import Testing
@testable import OhMyFile

struct CSVParserTests {
    @Test func parsesBasicCSV() {
        let table = CSVParser.parse("name,size\na,1\nb,2")

        #expect(table.header == ["name", "size"])
        #expect(table.rows == [["a", "1"], ["b", "2"]])
        #expect(table.truncated == false)
    }

    @Test func parsesQuotedCommasAndNewlines() {
        let table = CSVParser.parse("name,note\n\"a,b\",\"line1\nline2\"")

        #expect(table.rows == [["a,b", "line1\nline2"]])
    }

    @Test func handlesEscapedQuotes() {
        let table = CSVParser.parse("name\n\"say \"\"hi\"\"\"")

        #expect(table.rows == [["say \"hi\""]])
    }

    @Test func truncatesLargeInput() {
        let lines = (0...10).map { "value\($0)" }.joined(separator: "\n")
        let table = CSVParser.parse(lines, maxRows: 5)

        #expect(table.truncated)
        #expect(table.rows.count <= 5)
    }

    @Test func handlesCRLF() {
        let table = CSVParser.parse("a,b\r\n1,2\r\n")

        #expect(table.header == ["a", "b"])
        #expect(table.rows == [["1", "2"]])
    }
}
