//
//  FileLibrary.swift
//  OhMyFile
//
//  App Group 内的文件目录：收件箱 / 下载 / 回收站。
//  纯内核代码，不依赖 SwiftUI / UIKit；rootURL 可注入，便于测试。
//

import Foundation

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let size: Int64?
    let modifiedAt: Date?

    var id: URL { url }
    nonisolated var name: String { url.lastPathComponent }

    nonisolated init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        self.size = values?.fileSize.map(Int64.init)
        self.modifiedAt = values?.contentModificationDate
    }
}

enum LibraryDirectory: String, CaseIterable, Sendable {
    case inbox
    case downloads
    case trash

    nonisolated var folderName: String {
        switch self {
        case .inbox:
            return "Inbox"
        case .downloads:
            return "Downloads"
        case .trash:
            return "Trash"
        }
    }
}

struct FileLibrary: Sendable {
    nonisolated static let appGroupIdentifier = "group.me.zzhhoo.OhMyFile"
    nonisolated private static let pendingImportKey = "pendingImportCount"

    let rootURL: URL?

    nonisolated init(rootURL: URL? = FileLibrary.appGroupContainerURL) {
        self.rootURL = rootURL
    }

    nonisolated static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    nonisolated func directoryURL(for directory: LibraryDirectory) -> URL? {
        rootURL?.appendingPathComponent(directory.folderName, isDirectory: true)
    }

    nonisolated func files(in directory: LibraryDirectory) -> [FileItem] {
        if directory == .trash {
            return trashFiles()
        }

        guard let url = directoryURL(for: directory) else { return [] }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls
            .map(FileItem.init(url:))
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }

    nonisolated private func trashFiles() -> [FileItem] {
        guard let trash = directoryURL(for: .trash) else { return [] }

        let items = (try? FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []

        var files: [FileItem] = []

        for item in items {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDirectory {
                let urls = (try? FileManager.default.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                    options: .skipsHiddenFiles
                )) ?? []
                files.append(contentsOf: urls.map(FileItem.init(url:)))
            } else {
                // 兼容旧版本直接放在 Trash 根目录的文件。
                files.append(FileItem(url: item))
            }
        }

        return files.sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }

    nonisolated func moveToTrash(_ file: FileItem, from directory: LibraryDirectory) throws {
        guard directory != .trash, let trash = directoryURL(for: .trash) else { return }

        let target = trash.appendingPathComponent(directory.folderName, isDirectory: true)
        try ensureDirectory(target)
        let destination = uniqueURL(in: target, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
    }

    nonisolated static func trashSource(for url: URL) -> LibraryDirectory? {
        let folder = url.deletingLastPathComponent().lastPathComponent
        return LibraryDirectory.allCases.first { $0 != .trash && $0.folderName == folder }
    }

    @discardableResult
    nonisolated func restore(_ file: FileItem) throws -> URL? {
        let sourceFolder = file.url.deletingLastPathComponent().lastPathComponent
        let targetDirectory = LibraryDirectory.allCases.first {
            $0 != .trash && $0.folderName == sourceFolder
        } ?? .inbox

        guard let target = directoryURL(for: targetDirectory) else { return nil }

        try ensureDirectory(target)
        let destination = uniqueURL(in: target, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
        return destination
    }

    nonisolated func deletePermanently(_ file: FileItem) throws {
        try FileManager.default.removeItem(at: file.url)
    }

    nonisolated func availableFileName(in directory: LibraryDirectory, preferredName: String) -> String {
        guard let url = directoryURL(for: directory) else { return preferredName }
        return uniqueURL(in: url, fileName: preferredName).lastPathComponent
    }

    nonisolated func importData(_ data: Data, fileName: String) throws -> URL {
        guard let inbox = directoryURL(for: .inbox) else {
            throw FileLibraryError.storageUnavailable
        }

        try ensureDirectory(inbox)
        let destination = uniqueURL(in: inbox, fileName: fileName)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    nonisolated func importFile(from sourceURL: URL) throws -> URL {
        try importFile(from: sourceURL, fileName: sourceURL.lastPathComponent)
    }

    nonisolated func importFile(from sourceURL: URL, fileName: String) throws -> URL {
        guard let inbox = directoryURL(for: .inbox) else {
            throw FileLibraryError.storageUnavailable
        }

        try ensureDirectory(inbox)
        let destination = uniqueURL(in: inbox, fileName: fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    nonisolated static func directory(for url: URL) -> LibraryDirectory? {
        let library = FileLibrary()
        let parent = url.standardizedFileURL.deletingLastPathComponent()

        for directory in LibraryDirectory.allCases {
            guard let root = library.directoryURL(for: directory)?.standardizedFileURL else {
                continue
            }

            if parent.path == root.path {
                return directory
            }
        }

        return nil
    }

    nonisolated func rename(_ file: FileItem, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              trimmed != ".",
              trimmed != ".." else {
            throw FileLibraryError.invalidName
        }

        let directory = file.url.deletingLastPathComponent()
        let destination = uniqueURL(in: directory, fileName: trimmed)
        try FileManager.default.moveItem(at: file.url, to: destination)
        return destination
    }

    nonisolated func move(_ file: FileItem, to directory: LibraryDirectory) throws -> URL {
        guard let target = directoryURL(for: directory) else {
            throw FileLibraryError.storageUnavailable
        }

        try ensureDirectory(target)
        let destination = uniqueURL(in: target, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
        return destination
    }

    nonisolated func copy(_ file: FileItem) throws -> URL {
        let directory = file.url.deletingLastPathComponent()
        let base = (file.url.lastPathComponent as NSString).deletingPathExtension
        let pathExtension = (file.url.lastPathComponent as NSString).pathExtension
        let copyName = pathExtension.isEmpty ? "\(base) copy" : "\(base) copy.\(pathExtension)"
        let destination = uniqueURL(in: directory, fileName: copyName)
        try FileManager.default.copyItem(at: file.url, to: destination)
        return destination
    }

    nonisolated func moveAllToTrash(from directory: LibraryDirectory) throws {
        guard directory != .trash else {
            try emptyTrash()
            return
        }

        for file in files(in: directory) {
            try moveToTrash(file, from: directory)
        }
    }

    nonisolated func emptyTrash() throws {
        guard let trash = directoryURL(for: .trash) else { return }

        let urls = try FileManager.default.contentsOfDirectory(
            at: trash,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }

    nonisolated var cacheURL: URL? {
        rootURL?.appendingPathComponent("Cache", isDirectory: true)
    }

    nonisolated var temporaryURL: URL? {
        rootURL?.appendingPathComponent("Temporary", isDirectory: true)
    }

    nonisolated func storageUsage() -> StorageUsage {
        let categories = StorageCategory.allCases.map { category -> StorageCategoryUsage in
            let url: URL?

            switch category {
            case .inbox:
                url = directoryURL(for: .inbox)
            case .downloads:
                url = directoryURL(for: .downloads)
            case .trash:
                url = directoryURL(for: .trash)
            case .cache:
                url = cacheURL
            case .temporary:
                url = temporaryURL
            }

            let usage = url.map { directoryUsage(at: $0) } ?? (0, 0)
            return StorageCategoryUsage(category: category, bytes: usage.bytes, fileCount: usage.count)
        }

        return StorageUsage(categories: categories)
    }

    nonisolated func clearCache() throws {
        guard let cacheURL else { return }

        let items = (try? FileManager.default.contentsOfDirectory(
            at: cacheURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []

        for item in items {
            try FileManager.default.removeItem(at: item)
        }
    }

    nonisolated private func directoryUsage(at url: URL) -> (bytes: Int64, count: Int) {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return (0, 0)
        }

        var bytes: Int64 = 0
        var count = 0

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            bytes += Int64(values?.fileSize ?? 0)
            count += 1
        }

        return (bytes, count)
    }

    /// 读取并清空 Share Extension 留下的导入计数，用于回到 App 时提示。
    nonisolated static func consumePendingImportCount() -> Int {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return 0 }

        let count = defaults.integer(forKey: pendingImportKey)
        if count > 0 {
            defaults.removeObject(forKey: pendingImportKey)
        }
        return count
    }

    nonisolated private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    nonisolated private func uniqueURL(in directory: URL, fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let pathExtension = (fileName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(fileName)
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(pathExtension)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        }

        return candidate
    }
}

enum FileLibraryError: Error {
    case invalidName
    case storageUnavailable
}
