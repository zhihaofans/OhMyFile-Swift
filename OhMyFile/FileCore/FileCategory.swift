//
//  FileCategory.swift
//  OhMyFile
//
//  文件类型分类，用于列表筛选；UTType 优先，Office 扩展名兜底。
//

import Foundation
import UniformTypeIdentifiers

enum FileCategory: String, CaseIterable, Sendable {
    case all
    case image
    case video
    case audio
    case pdf
    case text
    case document
    case archive
    case other
}

enum FileCategoryResolver {
    nonisolated private static let documentExtensions: Set<String> = [
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "rtf", "pages", "numbers", "key", "odt", "ods", "odp"
    ]

    nonisolated private static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"
    ]

    nonisolated static func category(for url: URL) -> FileCategory {
        let type = FileCapabilityResolver.contentType(for: url)
        let pathExtension = url.pathExtension.lowercased()

        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .movie) {
            return .video
        }
        if type.conforms(to: .audio) {
            return .audio
        }
        if type.conforms(to: .pdf) {
            return .pdf
        }
        if documentExtensions.contains(pathExtension) {
            return .document
        }
        if type.conforms(to: .text)
            || type.conforms(to: .json)
            || type.conforms(to: .xml)
            || type.conforms(to: .spreadsheet)
            || type.conforms(to: .presentation) {
            return .text
        }
        if type.conforms(to: .zip) || archiveExtensions.contains(pathExtension) {
            return .archive
        }

        return .other
    }
}
