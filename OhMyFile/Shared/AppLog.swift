//
//  AppLog.swift
//  OhMyFile
//
//  统一日志门面：主 App 只调用 AppLog，不直接使用 print / 第三方日志。
//  subsystem 固定，供 T-80 用 OSLogStore 导出最近日志。
//

import OSLog

enum AppLog {
    nonisolated static let subsystem = "me.zzhhoo.OhMyFile"

    nonisolated static let general = Logger(subsystem: subsystem, category: "general")
    nonisolated static let imports = Logger(subsystem: subsystem, category: "import")
    nonisolated static let preview = Logger(subsystem: subsystem, category: "preview")
    nonisolated static let download = Logger(subsystem: subsystem, category: "download")
    nonisolated static let save = Logger(subsystem: subsystem, category: "save")
    nonisolated static let external = Logger(subsystem: subsystem, category: "external")
}
