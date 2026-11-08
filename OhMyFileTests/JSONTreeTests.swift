import Foundation
import Testing
@testable import OhMyFile

struct JSONTreeTests {
    @Test func parsesObject() throws {
        let node = try JSONTreeParser.parse(#"{"b": 2, "a": "x"}"#)

        #expect(node.value == .object)
        let children = try #require(node.children)
        #expect(children.map(\.key) == ["a", "b"])
        #expect(children[0].value == .string("x"))
        #expect(children[1].value == .number("2"))
    }

    @Test func parsesArrayAndScalars() throws {
        let node = try JSONTreeParser.parse(#"[true, null, 1.5]"#)

        #expect(node.value == .array)
        let children = try #require(node.children)
        #expect(children.map(\.value) == [.bool(true), .null, .number("1.5")])
    }

    @Test func rejectsInvalidJSON() {
        #expect(throws: (any Error).self) {
            try JSONTreeParser.parse("{invalid}")
        }
    }
}
