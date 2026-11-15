//
//  FileTimestamps.swift
//  OhMyFile
//
//  文件导入 / 删除时间记录（xattr），用于列表排序。
//

import Foundation

enum FileTimestamps {
    nonisolated static let importedAtKey = "me.zzhhoo.OhMyFile.importedAt"
    nonisolated static let deletedAtKey = "me.zzhhoo.OhMyFile.deletedAt"
    nonisolated static let originalPathKey = "me.zzhhoo.OhMyFile.originalPath"

    nonisolated static func setImported(at date: Date, for url: URL) {
        set(date.timeIntervalSince1970, key: importedAtKey, for: url)
    }

    nonisolated static func setDeleted(at date: Date, for url: URL) {
        set(date.timeIntervalSince1970, key: deletedAtKey, for: url)
    }

    nonisolated static func clearDeleted(for url: URL) {
        remove(key: deletedAtKey, for: url)
    }

    nonisolated static func setOriginalPath(_ path: String, for url: URL) {
        setString(path, key: originalPathKey, for: url)
    }

    nonisolated static func originalPath(for url: URL) -> String? {
        getString(key: originalPathKey, for: url)
    }

    nonisolated static func clearOriginalPath(for url: URL) {
        remove(key: originalPathKey, for: url)
    }

    nonisolated static func importedAt(for url: URL) -> Date? {
        get(key: importedAtKey, for: url)
    }

    nonisolated static func deletedAt(for url: URL) -> Date? {
        get(key: deletedAtKey, for: url)
    }

    nonisolated private static func set(_ timestamp: TimeInterval, key: String, for url: URL) {
        let data = Data(String(timestamp).utf8)

        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = setxattr(url.path, key, baseAddress, buffer.count, 0, 0)
        }
    }

    nonisolated private static func get(key: String, for url: URL) -> Date? {
        let size = getxattr(url.path, key, nil, 0, 0, 0)
        guard size > 0 else { return nil }

        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return getxattr(url.path, key, baseAddress, size, 0, 0)
        }
        guard read > 0,
              let string = String(data: data.prefix(read), encoding: .utf8),
              let interval = TimeInterval(string) else {
            return nil
        }

        return Date(timeIntervalSince1970: interval)
    }

    nonisolated private static func setString(_ value: String, key: String, for url: URL) {
        let data = Data(value.utf8)

        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = setxattr(url.path, key, baseAddress, buffer.count, 0, 0)
        }
    }

    nonisolated private static func getString(key: String, for url: URL) -> String? {
        let size = getxattr(url.path, key, nil, 0, 0, 0)
        guard size > 0 else { return nil }

        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return getxattr(url.path, key, baseAddress, size, 0, 0)
        }
        guard read > 0 else { return nil }

        return String(data: data.prefix(read), encoding: .utf8)
    }

    nonisolated private static func remove(key: String, for url: URL) {
        _ = removexattr(url.path, key, 0)
    }
}
