//
//  ShareViewController.swift
//  OhMyFileShareExtension
//
//  接收分享的文件，写入 App Group 共享收件箱，然后结束。
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        importAttachments()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func importAttachments() {
        guard let context = extensionContext,
              let items = context.inputItems as? [NSExtensionItem] else {
            extensionContext?.cancelRequest(withError: ImportError.noContent)
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            context.cancelRequest(withError: ImportError.noContent)
            return
        }

        Task {
            var importedCount = 0
            var firstError: Error?

            for provider in providers {
                do {
                    try await Self.importItem(from: provider)
                    importedCount += 1
                } catch {
                    firstError = firstError ?? error
                }
            }

            await MainActor.run {
                if importedCount > 0 {
                    UserDefaults(suiteName: "group.me.zzhhoo.OhMyFile")?.set(importedCount, forKey: "pendingImportCount")
                    self.extensionContext?.completeRequest(returningItems: nil)
                } else {
                    self.extensionContext?.cancelRequest(withError: firstError ?? ImportError.invalidItem)
                }
            }
        }
    }

    private nonisolated static func importItem(from provider: NSItemProvider) async throws {
        let inbox = try inboxURL()

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let url = try await loadObjectFileURL(from: provider)
                try copy(url, into: inbox, preferredName: provider.suggestedName)
                return
            } catch {
                // 回退到文件表示。
            }
        }

        for typeIdentifier in [
            UTType.fileURL.identifier,
            UTType.image.identifier,
            UTType.movie.identifier,
            UTType.data.identifier
        ] {
            guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
                continue
            }

            do {
                try await importFileRepresentation(
                    from: provider,
                    typeIdentifier: typeIdentifier,
                    into: inbox
                )
                return
            } catch {
                continue
            }
        }

        throw ImportError.unsupportedType
    }

    private nonisolated static func loadObjectFileURL(from provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            provider.loadObject(ofClass: NSURL.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let nsURL = object as? NSURL, nsURL.isFileURL else {
                    continuation.resume(throwing: ImportError.invalidItem)
                    return
                }

                continuation.resume(returning: nsURL as URL)
            }
        }
    }

    private nonisolated static func importFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        into inbox: URL
    ) async throws {
        let suggestedName = provider.suggestedName

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(throwing: ImportError.invalidItem)
                    return
                }

                do {
                    try copy(url, into: inbox, preferredName: suggestedName)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private nonisolated static func copy(
        _ source: URL,
        into inbox: URL,
        preferredName: String?
    ) throws {
        let accessing = source.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let sourceName = source.lastPathComponent
        let sourceExtension = (sourceName as NSString).pathExtension

        let fileName: String
        if let preferredName, !preferredName.isEmpty {
            let preferredExtension = (preferredName as NSString).pathExtension
            if preferredExtension.isEmpty, !sourceExtension.isEmpty {
                fileName = "\(preferredName).\(sourceExtension)"
            } else {
                fileName = preferredName
            }
        } else {
            fileName = sourceName
        }

        let destination = uniqueURL(in: inbox, fileName: fileName)
        try FileManager.default.copyItem(at: source, to: destination)

        // 列表展示导入时间，而不是原文件的创建 / 修改时间。
        let importedAt = Date()
        try FileManager.default.setAttributes(
            [.modificationDate: importedAt, .creationDate: importedAt],
            ofItemAtPath: destination.path
        )
    }

    private nonisolated static func inboxURL() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.me.zzhhoo.OhMyFile"
        ) else {
            throw ImportError.appGroupUnavailable
        }

        let inbox = container.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    private nonisolated static func uniqueURL(in directory: URL, fileName: String) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let pathExtension = (fileName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(fileName)
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(pathExtension)"
            candidate = directory.appendingPathComponent(name)
            index += 1
        }

        return candidate
    }

    private enum ImportError: LocalizedError {
        case noContent
        case unsupportedType
        case invalidItem
        case appGroupUnavailable

        var errorDescription: String? {
            switch self {
            case .noContent:
                return "没有可导入的内容"
            case .unsupportedType:
                return "不支持的文件类型"
            case .invalidItem:
                return "文件读取失败"
            case .appGroupUnavailable:
                return "无法访问共享存储"
            }
        }
    }
}
