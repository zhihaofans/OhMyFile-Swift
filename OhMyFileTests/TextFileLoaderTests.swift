import Foundation
import Testing
@testable import OhMyFile

struct TextFileLoaderTests {
    @Test func loadsUTF8Text() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-text-test.txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try "hello 世界".write(to: url, atomically: true, encoding: .utf8)

        let text = try TextFileLoader.load(url: url)
        #expect(text == "hello 世界")
    }

    @Test func rejectsOversizedFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-large-test.txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let data = Data(repeating: 0x61, count: Int(TextFileLoader.maxBytes) + 1)
        try data.write(to: url)

        #expect(throws: TextFileLoader.LoadingError.self) {
            try TextFileLoader.load(url: url)
        }
    }

    @Test func rejectsNonUTF8Data() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-binary-test.txt")
        defer { try? FileManager.default.removeItem(at: url) }

        try Data([0xFF, 0xFE, 0x00]).write(to: url)

        #expect(throws: TextFileLoader.LoadingError.self) {
            try TextFileLoader.load(url: url)
        }
    }
}
