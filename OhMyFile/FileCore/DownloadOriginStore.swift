//
//  DownloadOriginStore.swift
//  OhMyFile
//
//  已下载文件的源链接映射（文件名 → 原始 URL），持久化到 JSON。
//

import Foundation

struct DownloadOriginStore {
    let fileURL: URL?

    nonisolated init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("download-origins.json")
    }

    nonisolated func load() -> [String: URL] {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let strings = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        var origins: [String: URL] = [:]
        for (key, value) in strings {
            if let url = URL(string: value) {
                origins[key] = url
            }
        }
        return origins
    }

    nonisolated func save(_ origins: [String: URL]) {
        guard let fileURL else { return }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let strings = origins.mapValues(\.absoluteString)
        guard let data = try? JSONEncoder().encode(strings) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
