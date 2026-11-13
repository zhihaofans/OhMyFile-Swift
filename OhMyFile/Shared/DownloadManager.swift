//
//  DownloadManager.swift
//  OhMyFile
//
//  后台下载：URLSession background + 进度 / 取消 / 重试；
//  完成后用 AtomicFileWriter 原子移动到下载目录。
//

import OSLog
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class DownloadManager: NSObject {
    static let shared = DownloadManager()

    private(set) var tasks: [DownloadTask] = []
    private(set) var lastCompletedFileName: String?
    private(set) var completedCount = 0

    var backgroundSessionCompletionHandler: (() -> Void)?

    private let sessionIdentifier = "me.zzhhoo.OhMyFile.downloads"
    private let store = DownloadTaskStore(fileURL: DownloadTaskStore.defaultFileURL)
    private let originStore = DownloadOriginStore(fileURL: DownloadOriginStore.defaultFileURL)
    private var origins: [String: URL] = [:]
    private var session: URLSession!
    private var activeTasks: [UUID: URLSessionDownloadTask] = [:]
    private var lastPersist = Date.distantPast

    override init() {
        super.init()

        var restored = store.load().filter { $0.status == .downloading || $0.status == .pending }
        for index in restored.indices {
            restored[index].status = .failed
            restored[index].errorMessage = String(localized: "Download was interrupted.")
        }
        tasks = restored
        origins = originStore.load()
        pruneOrigins()
        migrateOriginsToXattrs()
        persist()

        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.isDiscretionary = false
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)

        session.getAllTasks { [weak self] systemTasks in
            guard let self else { return }
            Task { @MainActor in
                self.reconcile(systemTasks)
            }
        }
    }

    func resolveSuggestedFileName(urlString: String) async -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let name = response.suggestedFilename,
           !name.isEmpty {
            return name
        }

        let fallback = url.lastPathComponent
        return fallback.isEmpty ? nil : fallback
    }

    func start(urlString: String, fileName: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return false
        }

        let trimmedName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = trimmedName.isEmpty ? "download" : trimmedName

        let task = DownloadTask(
            id: UUID(),
            url: url,
            fileName: fileName,
            status: .pending,
            bytesWritten: 0,
            totalBytes: 0,
            errorMessage: nil,
            createdAt: Date()
        )

        tasks.insert(task, at: 0)
        persist()
        startSystemDownload(for: task.id)
        return true
    }

    func cancel(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks[id] = nil

        if let index = tasks.firstIndex(where: { $0.id == id }) {
            let fileName = tasks[index].url.lastPathComponent
            AppLog.download.info("download cancelled: \(fileName, privacy: .public)")
            tasks[index].status = .cancelled
            tasks[index].errorMessage = nil
        }
        persist()
    }

    func retry(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].status = .pending
        tasks[index].bytesWritten = 0
        tasks[index].totalBytes = 0
        tasks[index].errorMessage = nil
        persist()
        startSystemDownload(for: tasks[index].id)
    }

    func remove(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks[id] = nil
        tasks.removeAll { $0.id == id }
        persist()
        pruneOrigins()
    }

    /// 只保留下载目录与回收站下载子目录中仍存在的文件的源链接记录。
    func pruneOrigins() {
        let fileManager = FileManager.default
        let library = FileLibrary()
        var existing = Set<String>()

        if let downloads = library.directoryURL(for: .downloads),
           let names = try? fileManager.contentsOfDirectory(atPath: downloads.path) {
            existing.formUnion(names)
        }

        if let trash = library.directoryURL(for: .trash) {
            let trashDownloads = trash.appendingPathComponent(LibraryDirectory.downloads.folderName)
            if let names = try? fileManager.contentsOfDirectory(atPath: trashDownloads.path) {
                existing.formUnion(names)
            }
        }

        let pruned = origins.filter { existing.contains($0.key) }
        guard pruned.count != origins.count else { return }

        origins = pruned
        originStore.save(origins)
    }

    private func migrateOriginsToXattrs() {
        let library = FileLibrary()
        var directories: [URL] = []

        if let downloads = library.directoryURL(for: .downloads) {
            directories.append(downloads)
        }
        if let trash = library.directoryURL(for: .trash) {
            directories.append(
                trash.appendingPathComponent(LibraryDirectory.downloads.folderName)
            )
        }

        let fileManager = FileManager.default

        for directory in directories {
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ) else {
                continue
            }

            for url in urls where OriginURLStore.get(for: url) == nil {
                if let origin = origins[url.lastPathComponent] {
                    OriginURLStore.set(origin, for: url)
                }
            }
        }
    }

    private func startSystemDownload(for id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        let downloadTask = session.downloadTask(with: tasks[index].url)
        downloadTask.taskDescription = id.uuidString
        activeTasks[id] = downloadTask

        tasks[index].status = .downloading
        tasks[index].errorMessage = nil
        persist()
        let startedName = tasks[index].url.lastPathComponent
        AppLog.download.info("download started: \(startedName, privacy: .public)")
        downloadTask.resume()
    }

    private func reconcile(_ systemTasks: [URLSessionTask]) {
        for systemTask in systemTasks {
            guard let idString = systemTask.taskDescription,
                  let id = UUID(uuidString: idString),
                  let downloadTask = systemTask as? URLSessionDownloadTask else {
                continue
            }

            activeTasks[id] = downloadTask

            if let index = tasks.firstIndex(where: { $0.id == id }) {
                tasks[index].status = .downloading
                tasks[index].errorMessage = nil
            }
        }

        persist()
    }

    func originURL(for fileURL: URL) -> URL? {
        if let url = OriginURLStore.get(for: fileURL) {
            return url
        }
        return origins[fileURL.lastPathComponent]
    }

    func migrateOrigin(from oldName: String, to newName: String) {
        guard oldName != newName, let url = origins[oldName] else { return }
        origins[newName] = url
        origins[oldName] = nil
        originStore.save(origins)
    }

    private func markCompleted(id: UUID, fileName: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].status = .completed
        tasks[index].fileName = fileName
        tasks[index].errorMessage = nil
        lastCompletedFileName = fileName
        completedCount += 1
        AppLog.download.info("download completed: \(fileName, privacy: .public)")

        origins[fileName] = tasks[index].url
        originStore.save(origins)

        if let downloads = FileLibrary().directoryURL(for: .downloads) {
            OriginURLStore.set(
                tasks[index].url,
                for: downloads.appendingPathComponent(fileName)
            )
        }

        persist()
    }

    private func markFailed(id: UUID, message: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].status = .failed
        tasks[index].errorMessage = message
        persist()
    }

    private func persist() {
        store.save(tasks)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString) else {
            return
        }

        let fileName = downloadTask.originalRequest?.url?.lastPathComponent ?? "download"
        let library = FileLibrary()
        let availableName = library.availableFileName(in: .downloads, preferredName: fileName)

        guard let directory = library.directoryURL(for: .downloads) else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(availableName)
            try AtomicFileWriter.replaceItem(at: destination, withTemporaryFileAt: location)
        } catch {
            let nsError = error as NSError
            AppLog.download.error("save downloaded file failed: \(fileName, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")

            Task { @MainActor [weak self] in
                self?.markFailed(
                    id: id,
                    message: String(localized: "Unable to save the downloaded file.")
                )
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.markCompleted(id: id, fileName: availableName)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let idString = downloadTask.taskDescription,
              let id = UUID(uuidString: idString) else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self,
                  let index = self.tasks.firstIndex(where: { $0.id == id }) else {
                return
            }

            self.tasks[index].bytesWritten = totalBytesWritten
            self.tasks[index].totalBytes = max(totalBytesExpectedToWrite, 0)

            if let suggested = downloadTask.response?.suggestedFilename,
               !suggested.isEmpty,
               self.tasks[index].fileName != suggested {
                self.tasks[index].fileName = suggested
            }

            let now = Date()
            if now.timeIntervalSince(self.lastPersist) > 2 {
                self.lastPersist = now
                self.persist()
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }

        // 用户主动取消不算失败，保留「已取消」状态以便重试。
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled {
            return
        }

        guard let idString = task.taskDescription,
              let id = UUID(uuidString: idString) else {
            return
        }

        let failedName = task.originalRequest?.url?.lastPathComponent ?? "unknown"
        AppLog.download.error("download failed: \(failedName, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")

        Task { @MainActor [weak self] in
            self?.markFailed(id: id, message: error.localizedDescription)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor [weak self] in
            self?.backgroundSessionCompletionHandler?()
            self?.backgroundSessionCompletionHandler = nil
        }
    }
}
