import Foundation
import Testing
@testable import OhMyFile

struct MarkdownParserTests {
    @Test func parsesHeadingsAndParagraphs() {
        let blocks = MarkdownParser.parse("# Title\n\nHello **world**", extended: false)

        #expect(blocks == [
            .heading(level: 1, text: "Title"),
            .paragraph("Hello **world**")
        ])
    }

    @Test func parsesListsAndQuotes() {
        let blocks = MarkdownParser.parse("- item\n1. first\n> quote", extended: false)

        #expect(blocks == [
            .listItem(text: "item", ordered: false, number: nil, checked: nil),
            .listItem(text: "first", ordered: true, number: 1, checked: nil),
            .quote("quote")
        ])
    }

    @Test func parsesCodeBlockAndDivider() {
        let blocks = MarkdownParser.parse("```swift\nlet a = 1\n```\n---", extended: false)

        #expect(blocks == [
            .code("let a = 1", language: "swift"),
            .divider
        ])
    }

    @Test func parsesTasksOnlyWhenExtended() {
        let basic = MarkdownParser.parse("- [ ] todo", extended: false)
        let extended = MarkdownParser.parse("- [x] done", extended: true)

        #expect(basic == [
            .listItem(text: "[ ] todo", ordered: false, number: nil, checked: nil)
        ])
        #expect(extended == [
            .listItem(text: "done", ordered: false, number: nil, checked: true)
        ])
    }

    @Test func parsesTablesOnlyWhenExtended() {
        let text = "| Name | Size |\n| --- | --- |\n| a | 1 |"

        #expect(MarkdownParser.parse(text, extended: false).count == 1)
        #expect(MarkdownParser.parse(text, extended: true) == [
            .table(header: ["Name", "Size"], rows: [["a", "1"]])
        ])
    }

    @Test func joinsConsecutiveParagraphLines() {
        let blocks = MarkdownParser.parse("line one\nline two", extended: false)

        #expect(blocks == [.paragraph("line one\nline two")])
    }
}
