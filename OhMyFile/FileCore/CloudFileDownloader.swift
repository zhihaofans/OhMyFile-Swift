//
//  CloudFileDownloader.swift
//  OhMyFile
//
//  iCloud 云端文件按需下载：读取前确保本地已有数据。
//

import Foundation

enum CloudFileError: Error {
    case downloadTimeout
}

enum CloudFileDownloader {
    nonisolated static func ensureDownloaded(at url: URL) async throws {
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]

        guard let values = try? url.resourceValues(forKeys: keys),
              values.isUbiquitousItem == true else {
            return
        }

        if values.ubiquitousItemDownloadingStatus == .current {
            return
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        // 最多等待 30 秒，避免无限卡住。
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: 500_000_000)

            let status = try? url
                .resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus

            if status == .current {
                return
            }
        }

        throw CloudFileError.downloadTimeout
    }
}
