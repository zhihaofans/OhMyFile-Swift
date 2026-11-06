import Foundation
import Testing
@testable import OhMyFile

struct FileLibraryTests {
    private func makeLibrary() throws -> (library: FileLibrary, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-library-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (FileLibrary(rootURL: root), root)
    }

    private func makeFile(in directory: LibraryDirectory, root: URL, name: String) throws -> URL {
        let dir = root.appendingPathComponent(directory.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data("content".utf8).write(to: url)
        return url
    }

    @Test func moveToTrashRemovesFromInbox() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = try makeFile(in: .inbox, root: root, name: "note.txt")
        let file = FileItem(url: fileURL)

        try library.moveToTrash(file, from: .inbox)

        #expect(library.files(in: .inbox).isEmpty)
        #expect(library.files(in: .trash).map(\.name) == ["note.txt"])
    }

    @Test func restoreMovesBackToInbox() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = try makeFile(in: .inbox, root: root, name: "note.txt")
        try library.moveToTrash(FileItem(url: fileURL), from: .inbox)

        let trashed = try #require(library.files(in: .trash).first)
        try library.restore(trashed)

        #expect(library.files(in: .trash).isEmpty)
        #expect(library.files(in: .inbox).map(\.name) == ["note.txt"])
    }

    @Test func moveToTrashHandlesNameCollision() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let firstURL = try makeFile(in: .inbox, root: root, name: "note.txt")
        let secondURL = try makeFile(in: .inbox, root: root, name: "note-1.txt")
        try library.moveToTrash(FileItem(url: firstURL), from: .inbox)

        // 手动创建同名文件后再移动，验证自动加序号。
        try Data("second".utf8).write(to: root.appendingPathComponent("Trash/note.txt"))
        try library.moveToTrash(FileItem(url: secondURL), from: .inbox)

        let names = Set(library.files(in: .trash).map(\.name))
        #expect(names.contains("note.txt"))
        #expect(names.contains("note-1.txt"))
        #expect(names.count == 2)
    }

    @Test func emptyTrashDeletesEverything() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try makeFile(in: .inbox, root: root, name: "a.txt")
        let b = try makeFile(in: .inbox, root: root, name: "b.txt")
        try library.moveToTrash(FileItem(url: a), from: .inbox)
        try library.moveToTrash(FileItem(url: b), from: .inbox)

        try library.emptyTrash()

        #expect(library.files(in: .trash).isEmpty)
    }

    @Test func moveAllToTrashMovesEveryFile() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try makeFile(in: .inbox, root: root, name: "a.txt")
        _ = try makeFile(in: .inbox, root: root, name: "b.txt")

        try library.moveAllToTrash(from: .inbox)

        #expect(library.files(in: .inbox).isEmpty)
        #expect(library.files(in: .trash).count == 2)
    }
}
