//
//  ImportInbox.swift
//  OhMyFile
//
//  App Group 共享的收件箱目录；Share Extension 写入，主 App 读取。
//

import Foundation

struct InboxFile: Identifiable, Hashable, Sendable {
    let url: URL
    let size: Int64?
    let modifiedAt: Date?

    var id: URL { url }
    var name: String { url.lastPathComponent }

    nonisolated init(url: URL) {
        self.url = url
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        self.size = values?.fileSize.map(Int64.init)
        self.modifiedAt = values?.contentModificationDate
    }
}

enum ImportInbox {
    /// 与 OhMyFileShareExtension 中的 App Group 常量保持一致。
    nonisolated static let appGroupIdentifier = "group.me.zzhhoo.OhMyFile"

    nonisolated static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    nonisolated static var inboxURL: URL? {
        containerURL?.appendingPathComponent("Inbox", isDirectory: true)
    }

    nonisolated static func files() -> [InboxFile] {
        guard let inbox = inboxURL else { return [] }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        return urls
            .map(InboxFile.init(url:))
            .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
    }
}
