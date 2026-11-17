//
//  ZipPacker.swift
//  OhMyFile
//
//  把选中的文件 / 文件夹打包为 zip。
//

import Foundation
import ZIPFoundation

enum ZipPacker {
    /// 打包并返回写入的条目数。
    nonisolated static func pack(items: [URL], to zipURL: URL) throws -> Int {
        var entries: [(url: URL, path: String)] = []
        let fileManager = FileManager.default

        for item in items {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                let baseName = item.lastPathComponent
                guard let enumerator = fileManager.enumerator(
                    at: item,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) else {
                    continue
                }

                for case let child as URL in enumerator {
                    let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        continue
                    }

                    let relative = baseName + "/" + child.path
                        .replacingOccurrences(of: item.path + "/", with: "")
                    entries.append((child, relative))
                }
            } else {
                entries.append((item, item.lastPathComponent))
            }
        }

        let archive = try Archive(url: zipURL, accessMode: .create)
        var added = 0
        var seen = Set<String>()

        for entry in entries {
            guard !seen.contains(entry.path) else { continue }
            seen.insert(entry.path)

            try archive.addEntry(with: entry.path, fileURL: entry.url)
            added += 1
        }

        return added
    }
}
