import Foundation
import Testing
@testable import OhMyFile

struct StorageUsageTests {
    private func makeLibrary() throws -> (library: FileLibrary, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (FileLibrary(rootURL: root), root)
    }

    private func makeFile(root: URL, folder: String, name: String, bytes: Int) throws {
        let directory = root.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: directory.appendingPathComponent(name))
    }

    @Test func reportsPerCategoryUsage() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try makeFile(root: root, folder: "Inbox", name: "a.txt", bytes: 100)
        try makeFile(root: root, folder: "Downloads", name: "b.txt", bytes: 200)
        try makeFile(root: root, folder: "Trash/Inbox", name: "c.txt", bytes: 300)
        try makeFile(root: root, folder: "Cache", name: "cache.bin", bytes: 400)

        let usage = library.storageUsage()

        #expect(usage.usage(for: .inbox)?.bytes == 100)
        #expect(usage.usage(for: .downloads)?.bytes == 200)
        #expect(usage.usage(for: .trash)?.bytes == 300)
        #expect(usage.usage(for: .cache)?.bytes == 400)
        #expect(usage.usage(for: .temporary)?.bytes == 0)
        #expect(usage.totalBytes == 1000)
        #expect(usage.totalFileCount == 4)
    }

    @Test func clearCacheKeepsUserFiles() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try makeFile(root: root, folder: "Cache", name: "cache.bin", bytes: 400)
        try makeFile(root: root, folder: "Inbox", name: "note.txt", bytes: 100)

        try library.clearCache()

        #expect(library.storageUsage().usage(for: .cache)?.bytes == 0)
        #expect(library.storageUsage().usage(for: .inbox)?.bytes == 100)
    }

    @Test func countsFilesRecursivelyInTrash() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        try makeFile(root: root, folder: "Trash/Inbox", name: "a.txt", bytes: 10)
        try makeFile(root: root, folder: "Trash/Downloads", name: "b.txt", bytes: 20)

        let usage = library.storageUsage()

        #expect(usage.usage(for: .trash)?.fileCount == 2)
        #expect(usage.usage(for: .trash)?.bytes == 30)
    }
}
