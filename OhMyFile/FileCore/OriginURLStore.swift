//
//  OriginURLStore.swift
//  OhMyFile
//
//  把下载源 URL 写入文件扩展属性；文件改名 / 移动 / 进出回收站后仍随文件保留。
//

import Foundation

enum OriginURLStore {
    nonisolated static let attributeName = "me.zzhhoo.OhMyFile.originURL"

    nonisolated static func set(_ originURL: URL, for fileURL: URL) {
        let data = Data(originURL.absoluteString.utf8)

        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = setxattr(fileURL.path, attributeName, baseAddress, buffer.count, 0, 0)
        }
    }

    nonisolated static func get(for fileURL: URL) -> URL? {
        let path = fileURL.path
        let size = getxattr(path, attributeName, nil, 0, 0, 0)
        guard size > 0 else { return nil }

        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { buffer -> Int in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return getxattr(path, attributeName, baseAddress, size, 0, 0)
        }
        guard read > 0 else { return nil }

        guard let string = String(data: data.prefix(read), encoding: .utf8) else {
            return nil
        }

        return URL(string: string)
    }

    nonisolated static func remove(for fileURL: URL) {
        _ = removexattr(fileURL.path, attributeName, 0)
    }
}
