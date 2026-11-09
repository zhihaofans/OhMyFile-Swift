//
//  DeviceStorage.swift
//  OhMyFile
//
//  设备存储容量读取：总容量与可用空间（与 App 自身占用区分）。
//

import Foundation

struct DeviceStorage: Sendable {
    let totalBytes: Int64
    let availableBytes: Int64
}

enum DeviceStorageReader {
    nonisolated static func read() -> DeviceStorage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileLibrary.appGroupContainerURL

        guard let url else { return nil }

        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])

        guard let total = values?.volumeTotalCapacity else { return nil }

        return DeviceStorage(
            totalBytes: Int64(total),
            availableBytes: values?.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }
}
