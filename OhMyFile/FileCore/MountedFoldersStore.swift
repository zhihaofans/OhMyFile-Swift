//
//  MountedFoldersStore.swift
//  OhMyFile
//
//  已挂载外部文件夹：保存安全作用域书签，重启 App 后可重新解析访问。
//

import Foundation

struct MountedFolder: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let displayName: String
    let bookmark: Data

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        displayName: String? = nil,
        bookmark: Data
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName ?? name
        self.bookmark = bookmark
    }
}

struct MountedFoldersStore: Sendable {
    nonisolated static var defaultStorageURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OhMyFile", isDirectory: true)
            .appendingPathComponent("mounted-folders.json")
    }

    let storageURL: URL?

    nonisolated init(storageURL: URL? = MountedFoldersStore.defaultStorageURL) {
        self.storageURL = storageURL
    }

    nonisolated func folders() -> [MountedFolder] {
        guard let storageURL,
              let data = try? Data(contentsOf: storageURL),
              let items = try? JSONDecoder().decode([StoredFolder].self, from: data) else {
            return []
        }

        return items.map {
            MountedFolder(
                id: $0.id,
                name: $0.name,
                displayName: $0.displayName,
                bookmark: $0.bookmark
            )
        }
    }

    nonisolated func rename(_ folder: MountedFolder, to displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var items = folders()
        guard let index = items.firstIndex(where: { $0.id == folder.id }) else { return }

        let existing = items[index]
        items[index] = MountedFolder(
            id: existing.id,
            name: existing.name,
            displayName: trimmed,
            bookmark: existing.bookmark
        )
        try? save(items)
    }

    @discardableResult
    nonisolated func mount(_ url: URL) throws -> MountedFolder {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let folder = MountedFolder(id: UUID(), name: url.lastPathComponent, bookmark: bookmark)
        var items = folders()

        if !items.contains(where: { $0.name == folder.name && $0.bookmark == folder.bookmark }) {
            items.append(folder)
            try save(items)
        }

        return folder
    }

    /// 找到包含该文件的已挂载文件夹（返回所在目录）。
    nonisolated func containingFolder(for url: URL) -> (folder: MountedFolder, folderURL: URL)? {
        let filePath = url.standardizedFileURL.path

        for folder in folders() {
            guard let root = MountedFoldersStore.resolve(folder) else { continue }
            let rootPath = root.standardizedFileURL.path

            guard filePath == rootPath || filePath.hasPrefix(rootPath + "/") else {
                continue
            }

            return (folder, url.deletingLastPathComponent())
        }

        return nil
    }

    nonisolated func remove(_ folder: MountedFolder) {
        var items = folders()
        items.removeAll { $0.id == folder.id }
        try? save(items)
    }

    nonisolated static func resolve(_ folder: MountedFolder) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: folder.bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    nonisolated private func save(_ items: [MountedFolder]) throws {
        guard let storageURL else { return }

        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let stored = items.map {
            StoredFolder(
                id: $0.id,
                name: $0.name,
                displayName: $0.displayName,
                bookmark: $0.bookmark
            )
        }
        let data = try JSONEncoder().encode(stored)
        try data.write(to: storageURL, options: .atomic)
    }

    private struct StoredFolder: Codable {
        let id: UUID
        let name: String
        let displayName: String?
        let bookmark: Data
    }
}
