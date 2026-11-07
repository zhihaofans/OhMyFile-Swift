//
//  StorageUsage.swift
//  OhMyFile
//
//  存储占用统计模型；纯内核代码。
//

import Foundation

enum StorageCategory: String, CaseIterable, Sendable {
    case inbox
    case downloads
    case trash
    case cache
    case temporary
}

struct StorageCategoryUsage: Sendable, Identifiable {
    let category: StorageCategory
    let bytes: Int64
    let fileCount: Int

    var id: StorageCategory { category }
}

struct StorageUsage: Sendable {
    let categories: [StorageCategoryUsage]

    var totalBytes: Int64 {
        categories.reduce(0) { $0 + $1.bytes }
    }

    var totalFileCount: Int {
        categories.reduce(0) { $0 + $1.fileCount }
    }

    func usage(for category: StorageCategory) -> StorageCategoryUsage? {
        categories.first { $0.category == category }
    }
}
