//
//  RecentFilesStore.swift
//  OhMyFile
//
//  最近打开记录；纯内核代码，存储可注入，便于测试。
//

import Foundation

struct RecentEntry: Codable, Hashable, Identifiable, Sendable {
    let path: String
    let openedAt: Date

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

        var items = entries().filter {
            $0.path != url.path && FileManager.default.fileExists(atPath: $0.path)
        }
        items.insert(RecentEntry(path: url.path, openedAt: date), at: 0)

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
        let items = entries().filter { FileManager.default.fileExists(atPath: $0.path) }
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
