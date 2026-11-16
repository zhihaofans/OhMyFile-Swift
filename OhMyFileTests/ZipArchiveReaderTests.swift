import Foundation
import Testing
@testable import OhMyFile

struct ZipArchiveReaderTests {
    @Test func readsEntriesAndBuildsTree() throws {
        let data = makeZip(entries: [
            (name: "Docs/", data: Data(), isDirectory: true),
            (name: "Docs/note.txt", data: Data("hello".utf8), isDirectory: false),
            (name: "readme.md", data: Data("# hi".utf8), isDirectory: false)
        ])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zip-test-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)

        let archive = try ZipArchiveReader.read(url: url)
        #expect(archive.entries.count == 3)
        #expect(!archive.isEncrypted)

        let note = try #require(archive.entries.first { $0.name == "note.txt" })
        #expect(note.size == 5)
        #expect(!note.isDirectory)

        let tree = archive.tree()
        #expect(tree.folders.map(\.name) == ["Docs"])
        #expect(tree.files.map(\.name) == ["readme.md"])
        #expect(tree.folders.first?.files.map(\.name) == ["note.txt"])
    }

    @Test func recognizesBrowsableExtensions() {
        #expect(ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.zip")))
        #expect(ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.mcaddon")))
        #expect(ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.MCADDON")))
        #expect(ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.mcpack")))
        #expect(ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.mcworld")))
        #expect(!ZipArchiveReader.isZipFile(url: URL(fileURLWithPath: "/tmp/a.rar")))
    }

    @Test func rejectsNonZipData() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("zip-test-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a zip".utf8).write(to: url)

        #expect(throws: ZipArchiveError.self) {
            _ = try ZipArchiveReader.read(url: url)
        }
    }
}

private func makeZip(
    entries: [(name: String, data: Data, isDirectory: Bool)]
) -> Data {
    var local = Data()
    var central = Data()
    var count = 0

    for entry in entries {
        let nameData = Data(entry.name.utf8)
        let offset = UInt32(local.count)

        local.appendZipUInt32(0x04034b50)
        local.appendZipUInt16(20)
        local.appendZipUInt16(0)
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
        central.appendZipUInt16(0)
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
