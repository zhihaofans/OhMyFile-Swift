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
    let isDirectory: Bool
    let importedAt: Date?
    let deletedAt: Date?

    var id: URL { url }
    nonisolated var name: String { url.lastPathComponent }

    nonisolated init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(
            forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        )
        self.size = values?.fileSize.map(Int64.init)
        self.modifiedAt = values?.contentModificationDate
        self.isDirectory = values?.isDirectory ?? false
        self.importedAt = FileTimestamps.importedAt(for: url)
        self.deletedAt = FileTimestamps.deletedAt(for: url)
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
        return contents(at: url)
    }

    /// 列出目录内直接内容（文件与子目录，不递归）。
    nonisolated func contents(at url: URL) -> [FileItem] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls
            .map(FileItem.init(url:))
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }

    /// 递归列出目录下所有子文件夹（用于「移动到」目标选择）。
    nonisolated func folders(in directory: LibraryDirectory) -> [FileItem] {
        guard directory != .trash, let root = directoryURL(for: directory) else { return [] }

        var result: [FileItem] = []
        var stack = [root]

        while let current = stack.popLast() {
            let children = (try? FileManager.default.contentsOfDirectory(
                at: current,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )) ?? []

            for child in children {
                let item = FileItem(url: child)
                if item.isDirectory {
                    result.append(item)
                    stack.append(child)
                }
            }
        }

        return result.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// 递归列出目录下所有文件（不含文件夹）。
    nonisolated func allFiles(in directory: LibraryDirectory) -> [FileItem] {
        guard directory != .trash, let root = directoryURL(for: directory) else { return [] }

        var result: [FileItem] = []
        var stack = [root]

        while let current = stack.popLast() {
            for item in contents(at: current) {
                if item.isDirectory {
                    stack.append(item.url)
                } else {
                    result.append(item)
                }
            }
        }

        return result
    }

    /// 文件相对顶层目录的子目录路径（根目录文件返回空串）。
    nonisolated func relativeDirectoryPath(
        for url: URL,
        in directory: LibraryDirectory
    ) -> String? {
        guard let root = directoryURL(for: directory)?.standardizedFileURL else {
            return nil
        }

        let parent = url.standardizedFileURL.deletingLastPathComponent()
        guard parent.path == root.path || parent.path.hasPrefix(root.path + "/") else {
            return nil
        }

        if parent.path == root.path {
            return ""
        }

        return String(parent.path.dropFirst(root.path.count + 1))
    }

    nonisolated static func relativeDirectoryPath(
        for url: URL,
        in directory: LibraryDirectory
    ) -> String? {
        FileLibrary().relativeDirectoryPath(for: url, in: directory)
    }

    nonisolated func createDirectory(named name: String, in parent: URL) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              trimmed != ".",
              trimmed != ".." else {
            throw FileLibraryError.invalidName
        }

        try ensureDirectory(parent)
        let destination = uniqueURL(in: parent, fileName: trimmed)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        return destination
    }

    nonisolated func fileCount(in folderURL: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var count = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                count += 1
            }
        }
        return count
    }

    nonisolated func move(_ file: FileItem, to folderURL: URL) throws -> URL {
        try ensureDirectory(folderURL)
        let destination = uniqueURL(in: folderURL, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
        return destination
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

    @discardableResult
    nonisolated func moveToTrash(_ file: FileItem, from directory: LibraryDirectory) throws -> URL? {
        guard directory != .trash, let trash = directoryURL(for: .trash) else { return nil }

        let target = trash.appendingPathComponent(directory.folderName, isDirectory: true)
        try ensureDirectory(target)

        let relativePath: String
        if let root = directoryURL(for: directory)?.standardizedFileURL {
            let filePath = file.url.standardizedFileURL.path
            if filePath.hasPrefix(root.path + "/") {
                relativePath = String(filePath.dropFirst(root.path.count + 1))
            } else {
                relativePath = file.url.lastPathComponent
            }
        } else {
            relativePath = file.url.lastPathComponent
        }

        let destination = uniqueURL(in: target, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
        FileTimestamps.setDeleted(at: Date(), for: destination)
        FileTimestamps.setOriginalPath(relativePath, for: destination)
        return destination
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

        if let originalPath = FileTimestamps.originalPath(for: file.url), !originalPath.isEmpty {
            let desired = target.appendingPathComponent(originalPath)
            let parent = desired.deletingLastPathComponent()
            try ensureDirectory(parent)

            let destination = uniqueURL(in: parent, fileName: desired.lastPathComponent)
            try FileManager.default.moveItem(at: file.url, to: destination)
            FileTimestamps.clearDeleted(for: destination)
            FileTimestamps.clearOriginalPath(for: destination)
            return destination
        }

        try ensureDirectory(target)
        let destination = uniqueURL(in: target, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
        FileTimestamps.clearDeleted(for: destination)
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
        FileTimestamps.setImported(at: Date(), for: destination)
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
        FileTimestamps.setImported(at: Date(), for: destination)
        return destination
    }

    /// 文件所属的顶层目录（含子目录；回收站返回 .trash）。
    nonisolated static func rootDirectory(for url: URL) -> LibraryDirectory? {
        let library = FileLibrary()
        let standardized = url.standardizedFileURL

        for directory in LibraryDirectory.allCases {
            guard let root = library.directoryURL(for: directory)?.standardizedFileURL else {
                continue
            }

            if standardized.path == root.path || standardized.path.hasPrefix(root.path + "/") {
                return directory
            }
        }

        return nil
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
