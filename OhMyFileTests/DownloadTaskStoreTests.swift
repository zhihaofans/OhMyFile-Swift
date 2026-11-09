import Foundation
import Testing
@testable import OhMyFile

struct DownloadTaskStoreTests {
    private func makeStore() throws -> (store: DownloadTaskStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-downloads-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (DownloadTaskStore(fileURL: root.appendingPathComponent("downloads.json")), root)
    }

    private func makeTask(url: String, status: DownloadStatus) -> DownloadTask {
        DownloadTask(
            id: UUID(),
            url: URL(string: url)!,
            fileName: "file.bin",
            status: status,
            bytesWritten: 50,
            totalBytes: 100,
            errorMessage: nil,
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    @Test func savesAndLoadsTasks() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let task = makeTask(url: "https://example.com/file.bin", status: .downloading)
        store.save([task])

        let loaded = store.load()
        #expect(loaded == [task])
    }

    @Test func progressIsClamped() {
        let task = makeTask(url: "https://example.com/file.bin", status: .downloading)
        #expect(task.progress == 0.5)

        var completed = task
        completed.bytesWritten = 200
        #expect(completed.progress == 1)
    }
}
