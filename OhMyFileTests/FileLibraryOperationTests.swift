import Foundation
import Testing
@testable import OhMyFile

struct FileLibraryOperationTests {
    private func makeLibrary() throws -> (library: FileLibrary, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-ops-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (FileLibrary(rootURL: root), root)
    }

    private func makeFile(in directory: LibraryDirectory, root: URL, name: String) throws -> FileItem {
        let dir = root.appendingPathComponent(directory.folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data("content".utf8).write(to: url)
        return FileItem(url: url)
    }

    @Test func renamesFile() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try makeFile(in: .inbox, root: root, name: "old.txt")
        _ = try library.rename(file, to: "new.txt")

        #expect(library.files(in: .inbox).map(\.name) == ["new.txt"])
    }

    @Test func renameRejectsInvalidName() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try makeFile(in: .inbox, root: root, name: "old.txt")

        #expect(throws: FileLibraryError.self) {
            try library.rename(file, to: "bad/name.txt")
        }
    }

    @Test func renameHandlesCollision() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try makeFile(in: .inbox, root: root, name: "old.txt")
        _ = try makeFile(in: .inbox, root: root, name: "new.txt")

        _ = try library.rename(file, to: "new.txt")

        let names = Set(library.files(in: .inbox).map(\.name))
        #expect(names.contains("new.txt"))
        #expect(names.contains("new-1.txt"))
    }

    @Test func movesBetweenDirectories() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try makeFile(in: .inbox, root: root, name: "a.txt")
        _ = try library.move(file, to: .downloads)

        #expect(library.files(in: .inbox).isEmpty)
        #expect(library.files(in: .downloads).map(\.name) == ["a.txt"])
    }

    @Test func copyAddsCopySuffix() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let file = try makeFile(in: .inbox, root: root, name: "a.txt")
        _ = try library.copy(file)

        #expect(library.files(in: .inbox).count == 2)
        #expect(library.files(in: .inbox).map(\.name).contains("a copy.txt"))
    }

    @Test func importsExternalFileIntoInbox() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("external.txt")
        try Data("external".utf8).write(to: source)

        let imported = try library.importFile(from: source)

        #expect(imported.deletingLastPathComponent().lastPathComponent == "Inbox")
        #expect(library.files(in: .inbox).map(\.name) == ["external.txt"])
    }

    @Test func importFileHandlesNameCollision() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("external.txt")
        try Data("external".utf8).write(to: source)
        _ = try library.importFile(from: source)
        _ = try library.importFile(from: source)

        let names = Set(library.files(in: .inbox).map(\.name))
        #expect(names == ["external.txt", "external-1.txt"])
    }

    @Test func importDataWritesIntoInbox() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = try library.importData(Data("hello".utf8), fileName: "clip.txt")

        #expect(library.files(in: .inbox).map(\.name) == ["clip.txt"])
        #expect(try Data(contentsOf: url) == Data("hello".utf8))
    }

    @Test func importDataHandlesCollision() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try library.importData(Data("a".utf8), fileName: "clip.txt")
        _ = try library.importData(Data("b".utf8), fileName: "clip.txt")

        #expect(Set(library.files(in: .inbox).map(\.name)) == ["clip.txt", "clip-1.txt"])
    }

    @Test func availableFileNameAvoidsCollision() throws {
        let (library, root) = try makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try library.importData(Data("a".utf8), fileName: "clip.txt")

        #expect(library.availableFileName(in: .inbox, preferredName: "clip.txt") == "clip-1.txt")
        #expect(library.availableFileName(in: .inbox, preferredName: "other.txt") == "other.txt")
    }

    @Test func directoryLookupFromURL() throws {
        let library = FileLibrary()
        if let downloads = library.directoryURL(for: .downloads) {
            let inside = downloads.appendingPathComponent("file.txt")
            #expect(FileLibrary.directory(for: inside) == .downloads)
        }

        // 外部路径即使含有同名文件夹，也不能误判为 App 目录。
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-dir-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("Downloads/file.txt")

        #expect(FileLibrary.directory(for: outside) == nil)
    }
}
