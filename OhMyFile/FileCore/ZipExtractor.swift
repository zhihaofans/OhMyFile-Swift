//
//  ZipExtractor.swift
//  OhMyFile
//
//  zip 解压到新文件夹：校验越界路径、检查加密条目，不在主线程执行。
//

import Foundation
import ZIPFoundation

enum ZipExtractorError: Error, Equatable {
    case encrypted
    case invalidEntry
}

struct ZipExtractionResult: Sendable {
    let destinationURL: URL
    let fileCount: Int
}

enum ZipExtractor {
    nonisolated static func extract(
        archiveURL: URL,
        to destinationURL: URL
    ) throws -> ZipExtractionResult {
        if let info = try? ZipArchiveReader.read(url: archiveURL), info.isEncrypted {
            throw ZipExtractorError.encrypted
        }

        let archive = try Archive(url: archiveURL, accessMode: .read)
        try FileManager.default.createDirectory(
            at: destinationURL,
            withIntermediateDirectories: true
        )

        var fileCount = 0

        for entry in archive {
            let path = entry.path

            guard !path.hasPrefix("/"),
                  !path.split(separator: "/").contains("..") else {
                continue
            }

            let destination = destinationURL.appendingPathComponent(path)

            if entry.type == .directory {
                try FileManager.default.createDirectory(
                    at: destination,
                    withIntermediateDirectories: true
                )
            } else {
                try FileManager.default.createDirectory(
                    at: destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                _ = try archive.extract(entry, to: destination)
                fileCount += 1
            }
        }

        return ZipExtractionResult(destinationURL: destinationURL, fileCount: fileCount)
    }
}
