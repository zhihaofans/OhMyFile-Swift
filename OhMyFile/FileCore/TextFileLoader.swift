//
//  TextFileLoader.swift
//  OhMyFile
//
//  只读加载文本文件；纯内核代码，不依赖 SwiftUI / UIKit。
//

import Foundation

enum TextFileLoader {
    enum LoadingError: Error {
        case tooLarge
        case unsupportedEncoding
        case readFailed
    }

    nonisolated static let maxBytes: Int64 = 2_000_000

    nonisolated static func load(url: URL) throws -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let size = values?.fileSize, Int64(size) > maxBytes {
            throw LoadingError.tooLarge
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw LoadingError.readFailed
        }

        if Int64(data.count) > maxBytes {
            throw LoadingError.tooLarge
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw LoadingError.unsupportedEncoding
        }

        return text
    }
}
