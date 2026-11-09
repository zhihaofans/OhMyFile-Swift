//
//  DownloadTask.swift
//  OhMyFile
//
//  下载任务模型与 JSON 持久化；纯内核代码。
//

import Foundation

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
}

nonisolated struct DownloadTask: Codable, Identifiable, Equatable {
    let id: UUID
    let url: URL
    var fileName: String
    var status: DownloadStatus
    var bytesWritten: Int64
    var totalBytes: Int64
    var errorMessage: String?
    let createdAt: Date

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(bytesWritten) / Double(totalBytes))
    }
}

struct DownloadTaskStore {
    let fileURL: URL?

    nonisolated init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("downloads.json")
    }

    nonisolated func load() -> [DownloadTask] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DownloadTask].self, from: data)) ?? []
    }

    nonisolated func save(_ tasks: [DownloadTask]) {
        guard let fileURL else { return }

        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(tasks) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
