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
}
