//
//  AtomicFileWriter.swift
//  OhMyFile
//
//  通用原子写入：先写同目录临时文件，再一次性替换目标文件。
//  失败时目标文件保持原样，不留下半成品；可供文本保存与远程下载复用。
//

import Foundation

enum AtomicFileWriter {
    enum WriteError: Error {
        case writeFailed
    }

    nonisolated static func write(_ data: Data, to destinationURL: URL) throws {
        let directory = destinationURL.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(".atomic-\(UUID().uuidString).tmp")

        do {
            try data.write(to: tempURL, options: .atomic)
            try replaceItem(at: destinationURL, withTemporaryFileAt: tempURL)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw WriteError.writeFailed
        }
    }

    nonisolated static func replaceItem(
        at destinationURL: URL,
        withTemporaryFileAt tempURL: URL
    ) throws {
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(destinationURL, withItemAt: tempURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempURL)
            throw WriteError.writeFailed
        }
    }
}
