//
//  ZipArchiveReader.swift
//  OhMyFile
//
//  zip 只读浏览：读取中央目录（文件名 / 大小 / 日期 / 是否加密），不解压。
//  纯 Foundation 实现，不引入第三方依赖。
//

import Foundation

struct ZipEntry: Identifiable, Hashable, Sendable {
    let path: String
    let size: Int64?
    let modifiedAt: Date?
    let isDirectory: Bool
    let isEncrypted: Bool

    var id: String { path }

    nonisolated var name: String {
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        return trimmed.split(separator: "/").last.map(String.init) ?? trimmed
    }
}

struct ZipArchive: Sendable {
    let entries: [ZipEntry]
    let isEncrypted: Bool

    nonisolated func tree() -> ZipFolder {
        ZipFolder.build(from: entries)
    }
}

enum ZipArchiveError: Error, Equatable {
    case notZip
    case corrupted
    case unsupportedZIP64
}

struct ZipFolder: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let folders: [ZipFolder]
    let files: [ZipEntry]

    var id: String { path }

    nonisolated static func build(from entries: [ZipEntry]) -> ZipFolder {
        var folderPaths = Set<String>([""])

        for entry in entries {
            if entry.isDirectory {
                folderPaths.insert(entry.path)
            } else {
                var parts = entry.path.split(separator: "/").map(String.init)
                _ = parts.popLast()

                var prefix = ""
                for part in parts {
                    prefix += part + "/"
                    folderPaths.insert(prefix)
                }
            }
        }

        return buildNode(path: "", name: "", folderPaths: folderPaths, entries: entries)
    }

    nonisolated private static func buildNode(
        path: String,
        name: String,
        folderPaths: Set<String>,
        entries: [ZipEntry]
    ) -> ZipFolder {
        let childFolders = folderPaths
            .filter { isDirectChild(path: $0, of: path) }
            .sorted()
            .map { childPath in
                let folderName = childPath.dropLast().split(separator: "/").last.map(String.init) ?? childPath
                return buildNode(
                    path: childPath,
                    name: folderName,
                    folderPaths: folderPaths,
                    entries: entries
                )
            }

        let childFiles = entries
            .filter { !$0.isDirectory && isDirectChild(path: $0.path, of: path) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return ZipFolder(path: path, name: name, folders: childFolders, files: childFiles)
    }

    nonisolated private static func isDirectChild(path child: String, of parent: String) -> Bool {
        guard child != parent else { return false }

        let relative: String
        if parent.isEmpty {
            relative = child
        } else {
            guard child.hasPrefix(parent) else { return false }
            relative = String(child.dropFirst(parent.count))
        }

        let trimmed = relative.hasSuffix("/") ? String(relative.dropLast()) : relative
        return !trimmed.isEmpty && !trimmed.contains("/")
    }
}

enum ZipArchiveReader {
    nonisolated static func read(url: URL) throws -> ZipArchive {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        guard let eocdOffset = findEndOfCentralDirectory(in: data) else {
            throw ZipArchiveError.notZip
        }

        guard eocdOffset + 22 <= data.count else {
            throw ZipArchiveError.corrupted
        }

        let entryCount = Int(readUInt16(data, at: eocdOffset + 10))
        let centralSize = Int(readUInt32(data, at: eocdOffset + 12))
        let centralOffset = Int(readUInt32(data, at: eocdOffset + 16))

        if entryCount == 0xFFFF || centralSize == 0xFFFFFFFF || centralOffset == 0xFFFFFFFF {
            throw ZipArchiveError.unsupportedZIP64
        }

        guard centralOffset >= 0,
              centralSize >= 0,
              centralOffset <= data.count,
              centralOffset + centralSize <= data.count else {
            throw ZipArchiveError.corrupted
        }

        var entries: [ZipEntry] = []
        var isEncrypted = false
        var offset = centralOffset

        for _ in 0..<entryCount {
            guard offset + 46 <= data.count,
                  readUInt32(data, at: offset) == 0x02014b50 else {
                throw ZipArchiveError.corrupted
            }

            let flags = readUInt16(data, at: offset + 8)
            let modTime = readUInt16(data, at: offset + 12)
            let modDate = readUInt16(data, at: offset + 14)
            let size32 = readUInt32(data, at: offset + 24)
            let nameLength = Int(readUInt16(data, at: offset + 28))
            let extraLength = Int(readUInt16(data, at: offset + 30))
            let commentLength = Int(readUInt16(data, at: offset + 32))
            let localOffset = readUInt32(data, at: offset + 42)

            guard nameLength > 0,
                  offset + 46 + nameLength + extraLength + commentLength <= data.count else {
                throw ZipArchiveError.corrupted
            }

            if size32 == 0xFFFFFFFF || localOffset == 0xFFFFFFFF {
                throw ZipArchiveError.unsupportedZIP64
            }

            let nameData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLength))
            let name = decodeName(nameData)

            // 只读展示：跳过绝对路径与越界路径，避免 zip slip。
            if !name.isEmpty,
               !name.hasPrefix("/"),
               !name.split(separator: "/").contains("..") {
                let encrypted = (flags & 0x1) != 0
                isEncrypted = isEncrypted || encrypted

                entries.append(
                    ZipEntry(
                        path: name,
                        size: Int64(size32),
                        modifiedAt: dosDate(date: modDate, time: modTime),
                        isDirectory: name.hasSuffix("/"),
                        isEncrypted: encrypted
                    )
                )
            }

            offset += 46 + nameLength + extraLength + commentLength
        }

        return ZipArchive(entries: entries, isEncrypted: isEncrypted)
    }

    nonisolated private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }

        let searchStart = max(0, data.count - 22 - 65_535)
        var index = data.count - 22

        while index >= searchStart {
            if data[index] == 0x50,
               data[index + 1] == 0x4B,
               data[index + 2] == 0x05,
               data[index + 3] == 0x06 {
                return index
            }
            index -= 1
        }

        return nil
    }

    nonisolated private static func decodeName(_ data: Data) -> String {
        if let name = String(data: data, encoding: .utf8) {
            return name
        }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    nonisolated private static func dosDate(date: UInt16, time: UInt16) -> Date? {
        let day = Int(date & 0x1F)
        let month = Int((date >> 5) & 0x0F)
        let year = Int((date >> 9) & 0x7F) + 1980
        let hour = Int((time >> 11) & 0x1F)
        let minute = Int((time >> 5) & 0x3F)
        let second = Int(time & 0x1F) * 2

        guard month > 0, day > 0 else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        return Calendar(identifier: .gregorian).date(from: components)
    }

    nonisolated private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    nonisolated private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
