//
//  FileCapability.swift
//  OhMyFile
//
//  基于 UTType 的文件能力模型；纯内核代码，不依赖 SwiftUI / UIKit。
//

import Foundation
import UniformTypeIdentifiers

struct FileCapability {
    let contentType: UTType
    let canPreview: Bool
    let canEdit: Bool
    let canExport: Bool
}

enum FileCapabilityResolver {
    nonisolated static func capability(for url: URL) -> FileCapability {
        capability(for: contentType(for: url))
    }

    nonisolated static func contentType(for url: URL) -> UTType {
        if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return contentType
        }

        if let type = UTType(filenameExtension: url.pathExtension) {
            return type
        }

        return .data
    }

    nonisolated private static let officeIdentifiers: Set<String> = [
        "org.openxmlformats.wordprocessingml.document",
        "com.microsoft.word.doc",
        "org.openxmlformats.spreadsheetml.sheet",
        "com.microsoft.excel.xls",
        "org.openxmlformats.presentationml.presentation",
        "com.microsoft.powerpoint.ppt",
        "com.apple.pages",
        "com.apple.numbers",
        "com.apple.keynote",
        "com.apple.iwork.pages",
        "com.apple.iwork.numbers",
        "com.apple.iwork.keynote"
    ]

    nonisolated static func capability(for contentType: UTType) -> FileCapability {
        let canPreview = contentType.conforms(to: .image)
            || contentType.conforms(to: .movie)
            || contentType.conforms(to: .audio)
            || contentType.conforms(to: .pdf)
            || contentType.conforms(to: .text)
            || contentType.conforms(to: .spreadsheet)
            || contentType.conforms(to: .presentation)
            || contentType.conforms(to: .database)
            || contentType.conforms(to: .zip)
            || contentType.conforms(to: .json)
            || contentType.conforms(to: .xml)
            || officeIdentifiers.contains(contentType.identifier)

        let canEdit = contentType.conforms(to: .text)
            || contentType.conforms(to: .json)
            || contentType.conforms(to: .xml)
            || contentType.conforms(to: .spreadsheet)

        return FileCapability(
            contentType: contentType,
            canPreview: canPreview,
            canEdit: canEdit,
            canExport: true
        )
    }
}
