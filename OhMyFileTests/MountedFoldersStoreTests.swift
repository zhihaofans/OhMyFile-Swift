import Foundation
import Testing
@testable import OhMyFile

struct MountedFoldersStoreTests {
    @Test func mountsResolvesAndRemovesFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mounted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = root.appendingPathComponent("store.json")
        let store = MountedFoldersStore(storageURL: storage)

        let folder = try store.mount(root)
        #expect(store.folders().count == 1)
        #expect(store.folders().first?.name == root.lastPathComponent)
        #expect(MountedFoldersStore.resolve(folder) != nil)

        store.remove(folder)
        #expect(store.folders().isEmpty)
    }

    @Test func renamesMountedFolderNote() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mounted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = root.appendingPathComponent("store.json")
        let store = MountedFoldersStore(storageURL: storage)

        let folder = try store.mount(root)
        store.rename(folder, to: "我的笔记")

        #expect(store.folders().first?.displayName == "我的笔记")
        #expect(store.folders().first?.name == root.lastPathComponent)
        #expect(MountedFoldersStore.resolve(try #require(store.folders().first)) != nil)
    }

    @Test func locatesFileInsideMountedFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mounted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = root.appendingPathComponent("store.json")
        let store = MountedFoldersStore(storageURL: storage)
        let folder = try store.mount(root)

        let file = root.appendingPathComponent("note.txt")
        try Data("x".utf8).write(to: file)

        let location = try #require(store.containingFolder(for: file))
        #expect(location.folder.id == folder.id)
        #expect(location.folderURL.path == root.standardizedFileURL.path)

        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-\(UUID().uuidString).txt")
        #expect(store.containingFolder(for: outside) == nil)
    }

    @Test func mountingSameFolderTwiceKeepsSingleEntry() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mounted-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = root.appendingPathComponent("store.json")
        let store = MountedFoldersStore(storageURL: storage)

        let first = try store.mount(root)
        store.rename(first, to: "备注名")
        _ = try store.mount(root)

        let items = store.folders()
        #expect(items.count == 1)
        #expect(items.first?.displayName == "备注名")
    }
}
