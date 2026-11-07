//
//  FileSizeText.swift
//  OhMyFile
//
//  固定英文单位（B / KB / MB / GB），避免跟随系统语言显示「字节」。
//

import Foundation

func formattedFileSize(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0

    while value >= 1000, unitIndex < units.count - 1 {
        value /= 1000
        unitIndex += 1
    }

    if unitIndex == 0 {
        return "\(bytes) B"
    }

    return String(format: "%.1f %@", value, units[unitIndex])
}
