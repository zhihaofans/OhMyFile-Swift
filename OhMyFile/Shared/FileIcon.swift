//
//  FileIcon.swift
//  OhMyFile
//
//  按文件类型返回 SF Symbol 与颜色，列表 / 网格 / 缩略图回退共用。
//

import SwiftUI
import UniformTypeIdentifiers

func fileIcon(for url: URL) -> (symbol: String, color: Color) {
    let contentType = FileCapabilityResolver.contentType(for: url)

    if contentType.conforms(to: .image) {
        return ("photo", .orange)
    }
    if contentType.conforms(to: .movie) {
        return ("film", .purple)
    }
    if contentType.conforms(to: .audio) {
        return ("music.note", .pink)
    }
    if contentType.conforms(to: .pdf) {
        return ("doc.richtext", .red)
    }

    let wordExtensions: Set<String> = ["doc", "docx", "rtf", "pages", "odt"]
    let spreadsheetExtensions: Set<String> = ["xls", "xlsx", "numbers", "ods", "csv"]
    let presentationExtensions: Set<String> = ["ppt", "pptx", "key", "odp"]
    let pathExtension = url.pathExtension.lowercased()

    if wordExtensions.contains(pathExtension) {
        return ("doc.richtext", .blue)
    }
    if spreadsheetExtensions.contains(pathExtension) {
        return ("tablecells", .green)
    }
    if presentationExtensions.contains(pathExtension) {
        return ("rectangle.on.rectangle", .orange)
    }
    if contentType.conforms(to: .zip) {
        return ("archivebox", .brown)
    }
    if contentType.conforms(to: .spreadsheet) {
        return ("tablecells", .green)
    }
    if contentType.conforms(to: .text) || contentType.conforms(to: .json) || contentType.conforms(to: .xml) {
        return ("doc.text", .blue)
    }

    return ("questionmark", .gray)
}
