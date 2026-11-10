//
//  RecentFilesStore.swift
//  OhMyFile
//
//  最近打开记录；纯内核代码，存储可注入，便于测试。
//

import Foundation

nonisolated struct RecentEntry: Codable, Hashable, Identifiable, Sendable {
    let path: String
    let openedAt: Date
    var bookmark: Data? = nil

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

struct RecentFilesStore: Sendable {
    nonisolated static let maxCount = 50

    let storageURL: URL?

    nonisolated init(storageURL: URL?) {
        self.storageURL = storageURL
    }

    nonisolated static var defaultStorageURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("recent-files.json")
    }

    nonisolated static func record(_ url: URL) {
        RecentFilesStore(storageURL: defaultStorageURL).record(url, at: Date())
    }

    nonisolated func entries() -> [RecentEntry] {
        guard let storageURL, let data = try? Data(contentsOf: storageURL) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RecentEntry].self, from: data)) ?? []
    }

    nonisolated func record(_ url: URL, at date: Date) {
        guard storageURL != nil else { return }

        var items = entries().filter { entry in
            guard entry.path != url.path else { return false }

            // 外部文件没有常驻安全作用域，fileExists 可能不可靠，保留记录。
            if FileLibrary.directory(for: entry.url) == nil {
                return true
            }

            return FileManager.default.fileExists(atPath: entry.path)
        }

        let bookmark: Data?
        if FileLibrary.directory(for: url) == nil {
            bookmark = try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else {
            bookmark = nil
        }

        items.insert(RecentEntry(path: url.path, openedAt: date, bookmark: bookmark), at: 0)

        if items.count > Self.maxCount {
            items = Array(items.prefix(Self.maxCount))
        }
        save(items)
    }

    nonisolated func remove(_ url: URL) {
        save(entries().filter { $0.path != url.path })
    }

    nonisolated func clear() {
        save([])
    }

    nonisolated func pruneMissing() -> [RecentEntry] {
        let items = entries().filter { entry in
            // 外部文件保留，打开时再校验（无安全作用域时 fileExists 可能为 false）。
            if FileLibrary.directory(for: entry.url) == nil {
                return true
            }

            return FileManager.default.fileExists(atPath: entry.path)
        }
        save(items)
        return items
    }

    nonisolated private func save(_ items: [RecentEntry]) {
        guard let storageURL else { return }

        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
