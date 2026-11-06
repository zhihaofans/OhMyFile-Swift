import Foundation
import Testing
@testable import OhMyFile

struct RecentFilesStoreTests {
    private func makeStore() throws -> (store: RecentFilesStore, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-recent-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storage = root.appendingPathComponent("recent.json")
        return (RecentFilesStore(storageURL: storage), root)
    }

    private func makeFile(root: URL, name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("content".utf8).write(to: url)
        return url
    }

    @Test func recordsNewestFirst() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(root: root, name: "a.txt")
        let b = try makeFile(root: root, name: "b.txt")

        store.record(a, at: Date(timeIntervalSince1970: 100))
        store.record(b, at: Date(timeIntervalSince1970: 200))

        #expect(store.entries().map(\.name) == ["b.txt", "a.txt"])
    }

    @Test func recordingSameFileMovesItToFront() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(root: root, name: "a.txt")
        let b = try makeFile(root: root, name: "b.txt")

        store.record(a, at: Date(timeIntervalSince1970: 100))
        store.record(b, at: Date(timeIntervalSince1970: 200))
        store.record(a, at: Date(timeIntervalSince1970: 300))

        #expect(store.entries().map(\.name) == ["a.txt", "b.txt"])
        #expect(store.entries().count == 2)
    }

    @Test func capsAtMaxCount() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        for index in 0..<(RecentFilesStore.maxCount + 5) {
            let url = try makeFile(root: root, name: "file-\(index).txt")
            store.record(url, at: Date(timeIntervalSince1970: Double(index)))
        }

        #expect(store.entries().count == RecentFilesStore.maxCount)
    }

    @Test func clearRemovesAll() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(root: root, name: "a.txt")
        store.record(a, at: Date())

        store.clear()

        #expect(store.entries().isEmpty)
    }

    @Test func pruneMissingRemovesDeletedFiles() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(root: root, name: "a.txt")
        let b = try makeFile(root: root, name: "b.txt")
        store.record(a, at: Date(timeIntervalSince1970: 100))
        store.record(b, at: Date(timeIntervalSince1970: 200))

        try FileManager.default.removeItem(at: a)

        let pruned = store.pruneMissing()
        #expect(pruned.map(\.name) == ["b.txt"])
    }

    @Test func persistsAcrossInstances() throws {
        let (store, root) = try makeStore()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(root: root, name: "a.txt")
        store.record(a, at: Date(timeIntervalSince1970: 100))

        let reloaded = RecentFilesStore(storageURL: root.appendingPathComponent("recent.json"))
        #expect(reloaded.entries().map(\.name) == ["a.txt"])
    }
}
