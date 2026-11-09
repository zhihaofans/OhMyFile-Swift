import Foundation
import Testing
@testable import OhMyFile

struct OriginURLStoreTests {
    private func makeFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-origin-\(UUID().uuidString).bin")
        try Data("content".utf8).write(to: url)
        return url
    }

    @Test func writesAndReadsOriginURL() throws {
        let fileURL = try makeFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let origin = URL(string: "https://example.com/file.bin")!
        OriginURLStore.set(origin, for: fileURL)

        #expect(OriginURLStore.get(for: fileURL) == origin)
    }

    @Test func originURLSurvivesMove() throws {
        let fileURL = try makeFile()
        let movedURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("ohmyfile-origin-moved-\(UUID().uuidString).bin")
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: movedURL)
        }

        let origin = URL(string: "https://example.com/file.bin")!
        OriginURLStore.set(origin, for: fileURL)
        try FileManager.default.moveItem(at: fileURL, to: movedURL)

        #expect(OriginURLStore.get(for: movedURL) == origin)
    }

    @Test func removesOriginURL() throws {
        let fileURL = try makeFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        OriginURLStore.set(URL(string: "https://example.com/file.bin")!, for: fileURL)
        OriginURLStore.remove(for: fileURL)

        #expect(OriginURLStore.get(for: fileURL) == nil)
    }
}
