import Foundation
import Testing
@testable import OhMyFile

struct AtomicFileWriterTests {
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ohmyfile-atomic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func writesNewFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("note.txt")
        try AtomicFileWriter.write(Data("hello".utf8), to: target)

        #expect(try Data(contentsOf: target) == Data("hello".utf8))
    }

    @Test func overwritesExistingFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("note.txt")
        try Data("old".utf8).write(to: target)

        try AtomicFileWriter.write(Data("new".utf8), to: target)

        #expect(try Data(contentsOf: target) == Data("new".utf8))
    }

    @Test func failedReplaceKeepsOriginalFile() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let target = directory.appendingPathComponent("note.txt")
        try Data("original".utf8).write(to: target)

        let missingTemp = directory.appendingPathComponent("missing.tmp")

        #expect(throws: AtomicFileWriter.WriteError.self) {
            try AtomicFileWriter.replaceItem(at: target, withTemporaryFileAt: missingTemp)
        }
        #expect(try Data(contentsOf: target) == Data("original".utf8))
    }

    @Test func cleansUpTemporaryFileOnFailure() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let missingDirectory = directory.appendingPathComponent("missing", isDirectory: true)
        let target = missingDirectory.appendingPathComponent("note.txt")

        #expect(throws: AtomicFileWriter.WriteError.self) {
            try AtomicFileWriter.write(Data("x".utf8), to: target)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}
