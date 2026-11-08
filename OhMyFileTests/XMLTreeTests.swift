import Foundation
import Testing
@testable import OhMyFile

struct XMLTreeTests {
    @Test func parsesNestedElements() throws {
        let root = try XMLTreeParser.parse("<root><item id=\"1\">hello</item></root>")

        #expect(root.name == "root")
        #expect(root.children.count == 1)

        let item = try #require(root.children.first)
        #expect(item.name == "item")
        #expect(item.attributes == ["id": "1"])
        #expect(item.text == "hello")
    }

    @Test func rejectsInvalidXML() {
        #expect(throws: (any Error).self) {
            try XMLTreeParser.parse("<root><unclosed>")
        }
    }
}
