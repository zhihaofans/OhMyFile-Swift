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

    nonisolated func moveToTrash(_ file: FileItem, from directory: LibraryDirectory) throws {
        guard directory != .trash, let trash = directoryURL(for: .trash) else { return }

        try ensureDirectory(trash)
        let destination = uniqueURL(in: trash, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
    }

    nonisolated func restore(_ file: FileItem) throws {
        guard let inbox = directoryURL(for: .inbox) else { return }

        try ensureDirectory(inbox)
        let destination = uniqueURL(in: inbox, fileName: file.url.lastPathComponent)
        try FileManager.default.moveItem(at: file.url, to: destination)
    }

    nonisolated func deletePermanently(_ file: FileItem) throws {
        try FileManager.default.removeItem(at: file.url)
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
