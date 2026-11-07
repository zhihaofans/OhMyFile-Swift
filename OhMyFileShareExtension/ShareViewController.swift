//
//  ShareViewController.swift
//  OhMyFileShareExtension
//
//  接收分享的文件，写入 App Group 共享收件箱，然后结束。
//  失败或部分失败时在扩展内显示提示。
//

import OSLog
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private nonisolated static let logger = Logger(
        subsystem: "me.zzhhoo.OhMyFile.ShareExtension",
        category: "import"
    )

    private let spinner = UIActivityIndicatorView(style: .large)
    private let shareTaskID = UUID().uuidString

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
            showFailure(imported: 0, failed: 1, error: ImportError.noContent)
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else {
            showFailure(imported: 0, failed: 1, error: ImportError.noContent)
            return
        }

        Task {
            var importedCount = 0
            var failures: [Error] = []

            for provider in providers {
                do {
                    try await Self.importItem(from: provider)
                    importedCount += 1
                } catch {
                    failures.append(error)
                }
            }

            await MainActor.run {
                Self.logger.error("Import finished: imported=\(importedCount), failed=\(failures.count)")
                self.finish(imported: importedCount, failed: failures.count, firstError: failures.first)
            }
        }
    }

    private func finish(imported: Int, failed: Int, firstError: Error?) {
        if failed == 0 {
            UserDefaults(suiteName: "group.me.zzhhoo.OhMyFile")?.set(imported, forKey: "pendingImportCount")
            showSuccess(imported: imported)
            return
        }

        showFailure(imported: imported, failed: failed, error: firstError)
    }

    private func showSuccess(imported: Int) {
        let title = String(localized: "Import Complete")
        let message = String(format: String(localized: "Imported %ld files"), imported)

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Open OhMyFile"), style: .default) { [weak self] _ in
            self?.openMainAppAndFinish()
        })
        present(alert, animated: true)
    }

    private func openMainAppAndFinish() {
        var components = URLComponents()
        components.scheme = "ohmyfile"
        components.host = "share"
        components.queryItems = [URLQueryItem(name: "id", value: shareTaskID)]

        guard let url = components.url else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        // 优先沿 responder chain 打开；失败再尝试 extensionContext.open。
        if !openViaResponderChain(url) {
            extensionContext?.open(url, completionHandler: nil)
        }

        // 给系统一点时间处理打开请求，再结束扩展，避免唤起被取消。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func openViaResponderChain(_ url: URL) -> Bool {
        var responder: UIResponder? = self

        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return true
            }
            responder = current.next
        }

        return false
    }

    private func showFailure(imported: Int, failed: Int, error: Error?) {
        Self.logger.error("Showing failure alert: imported=\(imported), failed=\(failed), error=\(error?.localizedDescription ?? "nil")")
        let title: String
        let message: String

        if imported > 0 {
            title = String(localized: "Some files were not imported")
            message = String(
                format: String(localized: "Imported %ld, failed %ld"),
                imported,
                failed
            )
        } else {
            title = String(localized: "Import Failed")
            message = error?.localizedDescription ?? String(localized: "The file could not be read.")
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "Close"), style: .default) { [weak self] _ in
            if imported > 0 {
                UserDefaults(suiteName: "group.me.zzhhoo.OhMyFile")?.set(imported, forKey: "pendingImportCount")
            }
            self?.openMainAppAndFinish()
        })
        present(alert, animated: true)
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
                return String(localized: "No content to import.")
            case .unsupportedType:
                return String(localized: "Unsupported file type.")
            case .invalidItem:
                return String(localized: "The file could not be read.")
            case .appGroupUnavailable:
                return String(localized: "Shared storage is unavailable.")
            }
        }
    }
}
