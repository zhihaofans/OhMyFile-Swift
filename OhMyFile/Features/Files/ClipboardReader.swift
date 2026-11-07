//
//  ClipboardReader.swift
//  OhMyFile
//
//  读取系统剪贴板：文件 / 图片 / 文本 / NSItemProvider（相册视频等）。
//  provider 得到的文件会复制到临时目录，导入后清理，避免把大文件读进内存。
//

import Foundation
import UIKit
import UniformTypeIdentifiers

enum ClipboardContent {
    case data(Data)
    case file(URL, isTemporary: Bool)
}

struct ClipboardImport {
    let content: ClipboardContent
    let defaultFileName: String
}

enum ClipboardReader {
    static func load() async -> ClipboardImport? {
        let pasteboard = UIPasteboard.general
        let baseName = String(localized: "Clipboard")

        if let url = pasteboard.urls?.first(where: { $0.isFileURL }) {
            return ClipboardImport(
                content: .file(url, isTemporary: false),
                defaultFileName: defaultName(base: baseName, pathExtension: url.pathExtension)
            )
        }

        if let image = pasteboard.image, let data = image.pngData() {
            return ClipboardImport(
                content: .data(data),
                defaultFileName: "\(baseName).png"
            )
        }

        if let string = pasteboard.string, !string.isEmpty {
            return ClipboardImport(
                content: .data(Data(string.utf8)),
                defaultFileName: "\(baseName).txt"
            )
        }

        if let provider = pasteboard.itemProviders.first {
            return await loadFromProvider(provider, baseName: baseName)
        }

        return nil
    }

    private static func loadFromProvider(
        _ provider: NSItemProvider,
        baseName: String
    ) async -> ClipboardImport? {
        let types = [
            UTType.movie.identifier,
            UTType.video.identifier,
            UTType.image.identifier,
            UTType.data.identifier
        ]

        for type in types where provider.hasItemConformingToTypeIdentifier(type) {
            guard let copiedURL = await copyRepresentation(from: provider, type: type) else {
                continue
            }

            let pathExtension = copiedURL.pathExtension.isEmpty
                ? (UTType(type)?.preferredFilenameExtension ?? "dat")
                : copiedURL.pathExtension

            return ClipboardImport(
                content: .file(copiedURL, isTemporary: true),
                defaultFileName: defaultName(base: baseName, pathExtension: pathExtension)
            )
        }

        return nil
    }

    private static func copyRepresentation(
        from provider: NSItemProvider,
        type: String
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clipboard-\(UUID().uuidString)-\(url.lastPathComponent)")

                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private static func defaultName(base: String, pathExtension: String) -> String {
        pathExtension.isEmpty ? base : "\(base).\(pathExtension)"
    }
}
