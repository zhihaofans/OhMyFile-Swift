import Foundation
import Testing
@testable import OhMyFile

struct FileTimestampsTests {
    @Test func writesAndReadsTimestamps() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-ts-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("x".utf8).write(to: url)

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        FileTimestamps.setImported(at: date, for: url)
        FileTimestamps.setDeleted(at: date.addingTimeInterval(60), for: url)

        let item = FileItem(url: url)
        #expect(item.importedAt == date)
        #expect(item.deletedAt == date.addingTimeInterval(60))

        FileTimestamps.clearDeleted(for: url)
        #expect(FileItem(url: url).deletedAt == nil)
    }
}
