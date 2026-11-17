import Foundation
import Testing
@testable import OhMyFile

struct ZipOperationsTests {
    @Test func extractsZipToFolder() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zipops-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let zipURL = root.appendingPathComponent("test.zip")
        let zipData = makeStoreZip(entries: [
            (name: "Docs/", data: Data()),
            (name: "Docs/note.txt", data: Data("hello".utf8)),
            (name: "readme.md", data: Data("# hi".utf8))
        ])
        try zipData.write(to: zipURL)

        let destination = root.appendingPathComponent("out", isDirectory: true)
        let result = try ZipExtractor.extract(archiveURL: zipURL, to: destination)

        #expect(result.fileCount == 2)
        #expect(try String(contentsOf: destination.appendingPathComponent("Docs/note.txt"), encoding: .utf8) == "hello")
        #expect(try String(contentsOf: destination.appendingPathComponent("readme.md"), encoding: .utf8) == "# hi")
    }

    @Test func packsFilesAndFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zipops-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let fileA = root.appendingPathComponent("a.txt")
        try Data("A".utf8).write(to: fileA)

        let folder = root.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("B".utf8).write(to: folder.appendingPathComponent("b.txt"))

        let zipURL = root.appendingPathComponent("out.zip")
        let count = try ZipPacker.pack(items: [fileA, folder], to: zipURL)

        #expect(count == 2)

        let archive = try ZipArchiveReader.read(url: zipURL)
        #expect(Set(archive.entries.map(\.path)) == ["a.txt", "docs/b.txt"])
    }

    @Test func rejectsEncryptedArchive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zipops-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let zipURL = root.appendingPathComponent("encrypted.zip")
        let zipData = makeStoreZip(entries: [
            (name: "secret.txt", data: Data("hidden".utf8))
        ], encrypted: true)
        try zipData.write(to: zipURL)

        #expect(throws: ZipExtractorError.self) {
            _ = try ZipExtractor.extract(
                archiveURL: zipURL,
                to: root.appendingPathComponent("out", isDirectory: true)
            )
        }
    }
}

private func makeStoreZip(
    entries: [(name: String, data: Data)],
    encrypted: Bool = false
) -> Data {
    var local = Data()
    var central = Data()
    var count = 0
    let flags: UInt16 = encrypted ? 1 : 0

    for entry in entries {
        let nameData = Data(entry.name.utf8)
        let offset = UInt32(local.count)

        local.appendZipUInt32(0x04034b50)
        local.appendZipUInt16(20)
        local.appendZipUInt16(flags)
        local.appendZipUInt16(0)
        local.appendZipUInt16(0)
        local.appendZipUInt16(0)
        local.appendZipUInt32(0)
        local.appendZipUInt32(UInt32(entry.data.count))
        local.appendZipUInt32(UInt32(entry.data.count))
        local.appendZipUInt16(UInt16(nameData.count))
        local.appendZipUInt16(0)
        local.append(nameData)
        local.append(entry.data)

        central.appendZipUInt32(0x02014b50)
        central.appendZipUInt16(20)
        central.appendZipUInt16(20)
        central.appendZipUInt16(flags)
        central.appendZipUInt16(0)
        central.appendZipUInt16(0)
        central.appendZipUInt16(0)
        central.appendZipUInt32(0)
        central.appendZipUInt32(UInt32(entry.data.count))
        central.appendZipUInt32(UInt32(entry.data.count))
        central.appendZipUInt16(UInt16(nameData.count))
        central.appendZipUInt16(0)
        central.appendZipUInt16(0)
        central.appendZipUInt16(0)
        central.appendZipUInt16(0)
        central.appendZipUInt32(0)
        central.appendZipUInt32(offset)
        central.append(nameData)

        count += 1
    }

    var result = local
    result.append(central)
    let centralOffset = UInt32(local.count)

    result.appendZipUInt32(0x06054b50)
    result.appendZipUInt16(0)
    result.appendZipUInt16(0)
    result.appendZipUInt16(UInt16(count))
    result.appendZipUInt16(UInt16(count))
    result.appendZipUInt32(UInt32(central.count))
    result.appendZipUInt32(centralOffset)
    result.appendZipUInt16(0)

    return result
}

private extension Data {
    mutating func appendZipUInt16(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendZipUInt32(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
