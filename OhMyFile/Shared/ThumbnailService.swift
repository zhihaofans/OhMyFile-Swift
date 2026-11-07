//
//  ThumbnailService.swift
//  OhMyFile
//
//  图片 / 视频 / PDF 缩略图：QuickLookThumbnailing + 内存缓存 + 磁盘缓存。
//  磁盘缓存放 App Group 的 Cache/Thumbnails/，可被存储管理清理。
//

import CryptoKit
import Foundation
import QuickLookThumbnailing
import UIKit

final class ThumbnailService: @unchecked Sendable {
    static let shared = ThumbnailService()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL?

    private init() {
        memoryCache.countLimit = 200

        let base = FileLibrary.appGroupContainerURL?
            .appendingPathComponent("Cache", isDirectory: true)
            .appendingPathComponent("Thumbnails", isDirectory: true)
        cacheDirectory = base

        if let base {
            try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        }
    }

    func thumbnail(for url: URL, size: CGSize, scale: CGFloat) async -> UIImage? {
        let key = cacheKey(for: url, size: size, scale: scale)

        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        guard let image = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request)
            .uiImage else {
            return nil
        }

        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)
        return image
    }

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    private func cacheKey(for url: URL, size: CGSize, scale: CGFloat) -> String {
        let raw = "\(url.path)|\(Int(size.width))x\(Int(size.height))@\(scale)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadFromDisk(key: String) -> UIImage? {
        guard let cacheDirectory else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent("\(key).png")

        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let cacheDirectory, let data = image.pngData() else { return }
        let fileURL = cacheDirectory.appendingPathComponent("\(key).png")
        try? data.write(to: fileURL, options: .atomic)
    }
}
