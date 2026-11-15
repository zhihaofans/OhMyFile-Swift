//
//  FilesView.swift
//  OhMyFile
//
//  文件页：收件箱 / 下载 / 回收站。
//  删除为软删除（移入回收站），回收站可恢复或永久清空。
//

import Combine
import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilesView: View {
    let refreshToken: UUID
    let openInboxToken: UUID
    let initialDirectory: LibraryDirectory?

    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var counts: [LibraryDirectory: Int] = [:]
    @State private var mountedFolders: [MountedFolder] = []
    @State private var importedCount = 0
    @State private var showImportAlert = false
    @State private var openedDirectory: LibraryDirectory?
    @State private var didApplyInitialDirectory = false
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var now = Date()
    @State private var downloadManager = DownloadManager.shared
    @State private var showClipboardSheet = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isImportingMedia = false
    @State private var isImportingFromFiles = false
    @State private var importErrorMessage: String?

    @Environment(\.openURL) private var openURL
    @State private var showCameraChoice = false
    @State private var showCamera = false
    @State private var showScanner = false
    @State private var cameraAccessDenied = false

    private let library = FileLibrary()

    private var directories: [SystemDirectory] {
        [
            SystemDirectory(
                title: "Inbox",
                systemImage: "tray.fill",
                color: .blue,
                itemCount: counts[.inbox] ?? 0,
                directory: .inbox
            ),
            SystemDirectory(
                title: "Downloads",
                systemImage: "arrow.down.circle.fill",
                color: .purple,
                itemCount: counts[.downloads] ?? 0,
                directory: .downloads,
                subtitle: downloadSubtitle
            ),
            SystemDirectory(
                title: "Trash",
                systemImage: "trash.fill",
                color: .green,
                itemCount: counts[.trash] ?? 0,
                directory: .trash
            )
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        ForEach(directories) { directory in
                            NavigationLink {
                                FileListView(directory: directory.directory) {
                                    Task { await loadCounts() }
                                }
                            } label: {
                                DirectoryRow(directory: directory)
                            }
                        }
                    }

                    Section("External Folders") {
                        if mountedFolders.isEmpty {
                            Text("No external folders.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(mountedFolders) { folder in
                                Text(folder.name)
                            }
                        }
                    }

                } else if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } else if searchResults.isEmpty {
                    SearchEmptyRow()
                } else {
                    Section("Results") {
                        ForEach(searchResults) { result in
                            NavigationLink {
                                FilePreviewView(file: result.file)
                            } label: {
                                SearchResultRow(result: result, now: now)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Files")
            .searchable(text: $searchText, prompt: "Search")
            .task { await loadCounts() }
            .onAppear {
                guard !didApplyInitialDirectory else { return }
                didApplyInitialDirectory = true

                if let initialDirectory {
                    openedDirectory = initialDirectory
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .task(id: searchText) {
                await search()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadCounts() }
                }
            }
            .onChange(of: refreshToken) { _, _ in
                Task { await loadCounts() }
            }
            .onChange(of: openInboxToken) { _, _ in
                Task {
                    await loadCounts()
                    openedDirectory = .inbox
                }
            }
            .navigationDestination(item: $openedDirectory) { directory in
                FileListView(directory: directory) {
                    Task { await loadCounts() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Paste from Clipboard", systemImage: "doc.on.clipboard") {
                            showClipboardSheet = true
                        }
                        Button("Import from Files", systemImage: "folder") {
                            isImportingFromFiles = true
                        }
                        Button("Import from Photos", systemImage: "photo") {
                            showPhotosPicker = true
                        }
                        Button("Camera / Scan", systemImage: "camera") {
                            showCameraChoice = true
                        }
                        Button("New Folder", systemImage: "folder.badge.plus") {}
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Import Complete", isPresented: $showImportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Added \(importedCount) files to Inbox")
            }
            .sheet(isPresented: $showClipboardSheet) {
                ClipboardImportSheet {
                    importedCount = 1
                    showImportAlert = true
                    Task { await loadCounts() }
                }
            }
            .fileImporter(
                isPresented: $isImportingFromFiles,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importFiles(urls)
                case .failure(let error):
                    importErrorMessage = error.localizedDescription
                }
            }
            .photosPicker(
                isPresented: $showPhotosPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 20,
                matching: .images
            )
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                importPhotos(items)
                selectedPhotoItems = []
            }
            .confirmationDialog(
                "Camera / Scan",
                isPresented: $showCameraChoice,
                titleVisibility: .visible
            ) {
                Button("Take Photo") {
                    requestCameraThen { showCamera = true }
                }
                Button("Scan Document") {
                    requestCameraThen { showScanner = true }
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { capture in
                    handleCapture(capture)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner { images in
                    handleScan(images)
                }
                .ignoresSafeArea()
            }
            .alert("Camera Access Required", isPresented: $cameraAccessDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Allow camera access in Settings to take photos or scan documents.")
            }
            .overlay {
                if isImportingMedia {
                    ProgressView("Importing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .overlay(alignment: .top) {
                if let importErrorMessage {
                    Text(importErrorMessage)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                        .onTapGesture { self.importErrorMessage = nil }
                        .task(id: importErrorMessage) {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            self.importErrorMessage = nil
                        }
                }
            }
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // 防抖：输入变化会取消上一个 task。
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }

        let results = await Task.detached { [library, query] in
            LibraryDirectory.allCases.flatMap { directory -> [SearchResult] in
                let files = directory == .trash
                    ? library.files(in: directory)
                    : library.allFiles(in: directory)

                return files
                    .filter { $0.name.localizedStandardContains(query) }
                    .map { SearchResult(file: $0, directory: directory) }
            }
        }.value

        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false
    }

    private func requestCameraThen(_ action: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            action()
        case .notDetermined:
            Task {
                let granted = await Self.requestCameraAccess()
                if granted {
                    action()
                } else {
                    cameraAccessDenied = true
                }
            }
        default:
            cameraAccessDenied = true
        }
    }

    nonisolated private static func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func handleCapture(_ capture: CameraCapture) {
        isImportingMedia = true

        Task {
            defer { isImportingMedia = false }

            do {
                switch capture {
                case .photo(let image):
                    guard let data = image.jpegData(compressionQuality: 0.9) else {
                        importErrorMessage = String(localized: "Unable to save the photo.")
                        return
                    }
                    _ = try FileLibrary().importData(
                        data,
                        fileName: "\(String(localized: "Photo")).jpg"
                    )
                case .video(let url):
                    defer { try? FileManager.default.removeItem(at: url) }

                    let pathExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    _ = try FileLibrary().importFile(
                        from: url,
                        fileName: "\(String(localized: "Video")).\(pathExtension)"
                    )
                }

                importedCount = 1
                showImportAlert = true
                await loadCounts()
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func importFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        isImportingMedia = true

        Task {
            let outcome = await Task.detached { () -> (imported: Int, error: String?) in
                var imported = 0
                var firstError: String?

                for url in urls {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        _ = try FileLibrary().importFile(from: url)
                        imported += 1
                    } catch {
                        if firstError == nil {
                            firstError = error.localizedDescription
                        }
                    }
                }

                return (imported, firstError)
            }.value

            isImportingMedia = false

            if outcome.imported > 0 {
                importedCount = outcome.imported
                showImportAlert = true
            }

            if let error = outcome.error {
                importErrorMessage = error
            }

            await loadCounts()
        }
    }

    private func handleScan(_ images: [UIImage]) {
        guard !images.isEmpty, let data = ScannedPDF.make(from: images) else {
            importErrorMessage = String(localized: "Unable to create the scanned PDF.")
            return
        }

        isImportingMedia = true

        Task {
            defer { isImportingMedia = false }

            do {
                _ = try FileLibrary().importData(
                    data,
                    fileName: "\(String(localized: "Scan")).pdf"
                )
                importedCount = 1
                showImportAlert = true
                await loadCounts()
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        isImportingMedia = true

        Task {
            var imported = 0
            var failed = 0

            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    failed += 1
                    continue
                }

                let pathExtension = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
                let fileName = "\(String(localized: "Photo")).\(pathExtension)"

                do {
                    _ = try FileLibrary().importData(data, fileName: fileName)
                    imported += 1
                } catch {
                    failed += 1
                }
            }

            isImportingMedia = false
            importedCount = imported
            showImportAlert = imported > 0

            if failed > 0 {
                importErrorMessage = String(localized: "Unable to read the selected photos.")
            }

            await loadCounts()
        }
    }

    private var downloadSubtitle: String? {
        let tasks = downloadManager.tasks
        let failed = tasks.filter { $0.status == .failed }.count
        let downloading = tasks.filter { $0.status == .downloading || $0.status == .pending }.count
        let completed = tasks.filter { $0.status == .completed }.count

        guard failed > 0 || downloading > 0 else { return nil }

        return String(
            format: String(localized: "%ld failed · %ld downloading · %ld completed"),
            failed,
            downloading,
            completed
        )
    }

    private func loadCounts() async {
        let loaded = await Task.detached { [library] in
            Dictionary(uniqueKeysWithValues: LibraryDirectory.allCases.map { directory in
                (directory, library.files(in: directory).count)
            })
        }.value
        counts = loaded

        let pending = await Task.detached { FileLibrary.consumePendingImportCount() }.value
        if pending > 0 {
            importedCount = pending
            showImportAlert = true
        }
    }
}

private struct SearchResult: Identifiable {
    let file: FileItem
    let directory: LibraryDirectory

    var id: URL { file.url }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let now: Date

    @AppStorage("settings.relativeTime") private var relativeTime = true

    var body: some View {
        HStack(spacing: 12) {
            FileThumbnailView(file: result.file, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.file.name)

                Text("\(sourceTitle) · \(fileDetailText(for: result.file, relativeTime: relativeTime, now: now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var sourceTitle: String {
        var source = result.directory.localizedTitle

        if let sub = FileLibrary.relativeDirectoryPath(for: result.file.url, in: result.directory),
           !sub.isEmpty {
            source += "/" + sub
        }

        return source
    }
}

private struct SearchEmptyRow: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Results")
                .font(.headline)

            Text("No files match your search.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }
}

extension LibraryDirectory {
    var localizedTitle: String {
        switch self {
        case .inbox:
            return String(localized: "Inbox")
        case .downloads:
            return String(localized: "Downloads")
        case .trash:
            return String(localized: "Trash")
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .inbox:
            return "Inbox"
        case .downloads:
            return "Downloads"
        case .trash:
            return "Trash"
        }
    }
}

private struct FileListView: View {
    let directory: LibraryDirectory
    var folderURL: URL? = nil
    let onChanged: () -> Void

    @AppStorage("files.inboxSortField") private var sortFieldRaw = InboxSortField.added.rawValue
    @AppStorage("files.inboxSortAscending") private var sortAscending = false
    @AppStorage("files.viewMode") private var viewModeRaw = ViewMode.list.rawValue
    @AppStorage("files.categoryFilter") private var categoryFilterRaw = FileCategory.all.rawValue
    @AppStorage("settings.folderPriority") private var folderPriority = false

    @State private var files: [FileItem] = []
    @State private var pendingDeletion: Deletion?
    @State private var errorMessage: String?
    @State private var renameTarget: FileItem?
    @State private var renameText = ""
    @State private var isSelecting = false
    @State private var selectedPaths: Set<URL> = []
    @State private var now = Date()
    @State private var downloadManager = DownloadManager.shared
    @State private var showDownloadSheet = false
    @State private var downloadURL = ""
    @State private var downloadError: String?
    @State private var downloadNotice: String?
    @State private var sharedLink: SharedLink?
    @State private var downloadStep = DownloadStep.url
    @State private var clipboardHasText = false
    @State private var isResolvingURL = false
    @State private var pendingDownloadURL = ""
    @State private var resolvedFileName = ""
    @State private var showNewFolderAlert = false
    @State private var showNewFileSheet = false
    @State private var newFileToEdit: FileItem?
    @State private var infoTarget: FileItem?
    @State private var newFolderName = ""
    @State private var movingFile: FileItem?
    @State private var moveTargets: [FileItem] = []
    @State private var batchMoveRequest: BatchMoveRequest?

    private let library = FileLibrary()

    private var currentURL: URL? {
        folderURL ?? library.directoryURL(for: directory)
    }

    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRaw) ?? .list
    }

    private var categoryFilter: FileCategory {
        FileCategory(rawValue: categoryFilterRaw) ?? .all
    }

    private func addedDate(for file: FileItem) -> Date {
        let fallback = file.modifiedAt ?? .distantPast

        if directory == .trash {
            return file.deletedAt ?? fallback
        }
        return file.importedAt ?? fallback
    }

    private var addedSortTitle: String {
        switch directory {
        case .inbox:
            return String(localized: "Import Date")
        case .downloads:
            return String(localized: "Download Date")
        case .trash:
            return String(localized: "Deleted Date")
        }
    }

    private var filteredFiles: [FileItem] {
        guard categoryFilter != .all else { return sortedFiles }
        return sortedFiles.filter {
            $0.isDirectory || FileCategoryResolver.category(for: $0.url) == categoryFilter
        }
    }

    private var sortedFiles: [FileItem] {
        let files = files
        let ascending = sortAscending
        let sorted: [FileItem]

        switch InboxSortField(rawValue: sortFieldRaw) ?? .date {
        case .name:
            sorted = files.sorted {
                let result = $0.name.localizedStandardCompare($1.name)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
        case .date:
            sorted = files.sorted {
                let lhs = $0.modifiedAt ?? .distantPast
                let rhs = $1.modifiedAt ?? .distantPast
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .size:
            sorted = files.sorted {
                let lhs = $0.size ?? 0
                let rhs = $1.size ?? 0
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .added:
            sorted = files.sorted {
                let lhs = addedDate(for: $0)
                let rhs = addedDate(for: $1)
                return ascending ? lhs < rhs : lhs > rhs
            }
        }

        guard folderPriority else { return sorted }

        let folders = sorted.filter(\.isDirectory)
        let regularFiles = sorted.filter { !$0.isDirectory }
        return folders + regularFiles
    }

    var body: some View {
        Group {
            let hasDownloadTasks = directory == .downloads && !downloadManager.tasks.isEmpty

            if files.isEmpty, !hasDownloadTasks {
                emptyState
            } else if filteredFiles.isEmpty, !hasDownloadTasks {
                filterEmptyState
            } else if viewMode == .grid, !hasDownloadTasks {
                grid
            } else {
                list
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                HStack(spacing: 12) {
                    Button {
                        toggleSelectAll()
                    } label: {
                        Label(isAllSelected ? "Deselect All" : "Select All", systemImage: "checkmark.circle")
                    }
                    .disabled(files.isEmpty)

                    if directory == .trash {
                        Button {
                            restoreSelected()
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(selectedPaths.isEmpty)
                    }

                    if directory != .trash {
                        Button {
                            batchMoveRequest = BatchMoveRequest(files: selectedFiles)
                        } label: {
                            Label("Move To", systemImage: "folder")
                        }
                        .disabled(selectedFiles.isEmpty)
                    }

                    Button(role: .destructive) {
                        pendingDeletion = .deleteSelected
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedPaths.isEmpty)

                    Spacer()

                    Text("\(selectedPaths.count)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.regularMaterial)
            }
        }
        .onChange(of: downloadManager.completedCount) { _, _ in
            if let fileName = downloadManager.lastCompletedFileName {
                downloadNotice = fileName
            }
            Task { await reload() }
        }
        .sheet(isPresented: $showDownloadSheet) {
            NavigationStack {
                Form {
                    if downloadStep == .url {
                        HStack {
                            TextField("Enter URL", text: $downloadURL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            if clipboardHasText {
                                Button("Paste") {
                                    pasteClipboardURL()
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        TextField("File Name", text: $resolvedFileName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Text(pendingDownloadURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let downloadError {
                        Text(downloadError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .navigationTitle("Download")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showDownloadSheet = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        if downloadStep == .url {
                            Button {
                                resolveURL()
                            } label: {
                                if isResolvingURL {
                                    ProgressView()
                                } else {
                                    Text("Next")
                                }
                            }
                            .disabled(
                                downloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || isResolvingURL
                            )
                        } else {
                            Button("Download") {
                                startDownload()
                            }
                            .disabled(
                                resolvedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        }
                    }
                }
            }
            .presentationDetents([.height(260)])
        }
        .sheet(item: $sharedLink) { link in
            ShareSheet(items: [link.url])
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $movingFile) { file in
            let parentURL = file.url.deletingLastPathComponent().standardizedFileURL
            let rootURL = library.directoryURL(for: directory)?.standardizedFileURL
            let isInRoot = rootURL?.path == parentURL.path
            let targets = library.folders(in: directory).filter {
                $0.url.standardizedFileURL.path != parentURL.path
            }

            NavigationStack {
                List {
                    if !isInRoot {
                        Section {
                            Button {
                                moveToRoot(file)
                            } label: {
                                Label("Root Folder", systemImage: "folder")
                            }
                        }
                    }

                    if !targets.isEmpty {
                        Section("Folders") {
                            ForEach(targets) { folder in
                                Button {
                                    moveToFolder(file, target: folder)
                                } label: {
                                    Label(folder.name, systemImage: "folder")
                                }
                            }
                        }
                    }

                    if isInRoot, targets.isEmpty {
                        Section {
                            Text("No other folders to move to.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Move To")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            movingFile = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $batchMoveRequest) { request in
            NavigationStack {
                List {
                    Section {
                        Button {
                            moveBatch(request.files, to: library.directoryURL(for: directory))
                        } label: {
                            Label("Root Folder", systemImage: "folder")
                        }
                    }

                    Section("Folders") {
                        ForEach(library.folders(in: directory)) { folder in
                            Button {
                                moveBatch(request.files, to: folder.url)
                            } label: {
                                Label(folder.name, systemImage: "folder")
                            }
                        }
                    }
                }
                .navigationTitle("Move To")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            batchMoveRequest = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let downloadNotice {
                Text(String(format: String(localized: "Download Complete: %@"), downloadNotice))
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .onTapGesture { self.downloadNotice = nil }
                    .task(id: downloadNotice) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self.downloadNotice = nil
                    }
            }
        }
        .navigationTitle(folderURL.map { LocalizedStringKey($0.lastPathComponent) } ?? titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if directory == .downloads {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let pasteboard = UIPasteboard.general
                        clipboardHasText = pasteboard.hasStrings || pasteboard.hasURLs
                        downloadStep = .url
                        showDownloadSheet = true
                    } label: {
                        if isResolvingURL {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(isResolvingURL)
                    .accessibilityLabel("Download")
                }
            }

            if viewMode == .list, !filteredFiles.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleSelection()
                    } label: {
                        Image(systemName: isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .accessibilityLabel(isSelecting ? "Done" : "Select")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if directory != .trash {
                        Button {
                            showNewFileSheet = true
                        } label: {
                            Label("New File", systemImage: "doc.badge.plus")
                        }
                        .disabled(isSelecting)

                        Button {
                            newFolderName = ""
                            showNewFolderAlert = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        .disabled(isSelecting)

                        Divider()
                    }

                    Button {
                        viewModeRaw = (viewMode == .grid ? ViewMode.list : ViewMode.grid).rawValue
                    } label: {
                        Label(
                            viewMode == .grid ? "List" : "Grid",
                            systemImage: viewMode == .grid ? "list.bullet" : "square.grid.2x2"
                        )
                    }
                    .disabled(isSelecting)

                    Divider()

                    Picker("Filter", selection: $categoryFilterRaw) {
                        Text("All").tag(FileCategory.all.rawValue)
                        Text("Images").tag(FileCategory.image.rawValue)
                        Text("Videos").tag(FileCategory.video.rawValue)
                        Text("Audio").tag(FileCategory.audio.rawValue)
                        Text("PDF").tag(FileCategory.pdf.rawValue)
                        Text("Text").tag(FileCategory.text.rawValue)
                        Text("Documents").tag(FileCategory.document.rawValue)
                        Text("Archives").tag(FileCategory.archive.rawValue)
                        Text("Other").tag(FileCategory.other.rawValue)
                    }

                    Divider()

                    Picker("Sort By", selection: $sortFieldRaw) {
                        Text("Name").tag(InboxSortField.name.rawValue)
                        Text(addedSortTitle).tag(InboxSortField.added.rawValue)
                        Text("Modified").tag(InboxSortField.date.rawValue)
                        Text("Size").tag(InboxSortField.size.rawValue)
                    }
                    Picker("Order", selection: $sortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(confirmationButtonTitle, role: .destructive) {
                confirmDeletion()
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(confirmationMessage)
        }
        .alert(
            "New Folder",
            isPresented: $showNewFolderAlert
        ) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                createFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a folder name.")
        }
        .alert(
            "Rename",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField("File name", text: $renameText)
            Button("Rename") {
                performRename()
            }
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
        } message: {
            Text("Enter a new name.")
        }
        .sheet(isPresented: $showNewFileSheet) {
            NewFileView(directory: directory, folderURL: folderURL) { url in
                Task { await reload() }
                onChanged()

                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    newFileToEdit = FileItem(url: url)
                }
            }
        }
        .sheet(item: $infoTarget) { file in
            FileInfoView(file: file)
        }
        .sheet(item: $newFileToEdit) { file in
            NavigationStack {
                TextEditorView(file: file, text: "") {
                    Task { await reload() }
                }
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .onTapGesture { self.errorMessage = nil }
                    .task(id: errorMessage) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        self.errorMessage = nil
                    }
            }
        }
    }

    private var list: some View {
        List(selection: $selectedPaths) {
            if directory == .downloads, !downloadManager.tasks.isEmpty {
                Section("Downloads") {
                    ForEach(downloadManager.tasks) { task in
                        DownloadRow(
                            task: task,
                            onCancel: { downloadManager.cancel(id: task.id) },
                            onRetry: { downloadManager.retry(id: task.id) },
                            onRemove: { downloadManager.remove(id: task.id) }
                        )
                    }
                }
            }

            ForEach(filteredFiles) { file in
                if isSelecting {
                    FileListRow(file: file, now: now)
                        .tag(file.url)
                } else if file.isDirectory {
                    NavigationLink {
                        FileListView(directory: directory, folderURL: file.url) {
                            onChanged()
                        }
                    } label: {
                        FileListRow(file: file, now: now)
                    }
                    .swipeActions(edge: .trailing) {
                        trailingActions(for: file)
                    }
                    .contextMenu {
                        contextMenuActions(for: file)
                    }
                } else {
                    NavigationLink {
                        FilePreviewView(file: file)
                    } label: {
                        FileListRow(file: file, now: now)
                    }
                    .swipeActions(edge: .trailing) {
                        trailingActions(for: file)
                    }
                    .contextMenu {
                        contextMenuActions(for: file)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(isSelecting ? .active : .inactive))
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 12)],
                spacing: 12
            ) {
                ForEach(filteredFiles) { file in
                    if file.isDirectory {
                        NavigationLink {
                            FileListView(directory: directory, folderURL: file.url) {
                                onChanged()
                            }
                        } label: {
                            FileGridCell(file: file, now: now)
                                .dropDestination(for: URL.self) { urls, _ in
                                    dropFiles(urls, into: file)
                                }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            contextMenuActions(for: file)
                        }
                    } else {
                        NavigationLink {
                            FilePreviewView(file: file)
                        } label: {
                            FileGridCell(file: file, now: now)
                                .draggable(file.url)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            contextMenuActions(for: file)
                        }
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func trailingActions(for file: FileItem) -> some View {
        if directory == .trash {
            Button {
                infoTarget = file
            } label: {
                Label("File Info", systemImage: "info.circle")
            }

            Button {
                restore(file)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }

            Button(role: .destructive) {
                pendingDeletion = .deletePermanently(file)
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                pendingDeletion = .moveToTrash(file)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func contextMenuActions(for file: FileItem) -> some View {
        if directory == .trash {
            Button {
                restore(file)
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }

            Button(role: .destructive) {
                pendingDeletion = .deletePermanently(file)
            } label: {
                Label("Delete Permanently", systemImage: "trash")
            }
        } else if file.isDirectory {
            Button {
                infoTarget = file
            } label: {
                Label("File Info", systemImage: "info.circle")
            }

            Button {
                beginRename(file)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                pendingDeletion = .moveToTrash(file)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        } else {
            Button {
                infoTarget = file
            } label: {
                Label("File Info", systemImage: "info.circle")
            }

            Button {
                beginRename(file)
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                copy(file)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            Button {
                beginMove(file)
            } label: {
                Label("Move To", systemImage: "folder")
            }

            if let origin = downloadManager.originURL(for: file.url) {
                Button {
                    sharedLink = SharedLink(url: origin)
                } label: {
                    Label("Share Link", systemImage: "link")
                }
            }

            Divider()

            Button(role: .destructive) {
                pendingDeletion = .moveToTrash(file)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            emptyTitleKey,
            systemImage: emptySymbol,
            description: Text(emptyDescriptionKey)
        )
    }

    private var filterEmptyState: some View {
        ContentUnavailableView(
            "No Results",
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("No files match the filter.")
        )
    }

    private var titleKey: LocalizedStringKey {
        switch directory {
        case .inbox:
            return "Inbox"
        case .downloads:
            return "Downloads"
        case .trash:
            return "Trash"
        }
    }

    private var emptyTitleKey: LocalizedStringKey {
        if folderURL != nil {
            return "Folder is Empty"
        }

        switch directory {
        case .inbox:
            return "Inbox is Empty"
        case .downloads:
            return "Downloads is Empty"
        case .trash:
            return "Trash is Empty"
        }
    }

    private var emptySymbol: String {
        if folderURL != nil {
            return "folder"
        }

        switch directory {
        case .inbox:
            return "tray"
        case .downloads:
            return "arrow.down.circle"
        case .trash:
            return "trash"
        }
    }

    private var emptyDescriptionKey: LocalizedStringKey {
        if folderURL != nil {
            return "Files moved into this folder will appear here."
        }

        switch directory {
        case .inbox:
            return "Files shared to OhMyFile will appear here."
        case .downloads:
            return "Files downloaded to OhMyFile will appear here."
        case .trash:
            return "Deleted files will appear here."
        }
    }

    private var confirmationTitle: String {
        switch pendingDeletion {
        case .moveToTrash:
            return String(localized: "Move to Trash?")
        case .deletePermanently:
            return String(localized: "Delete Permanently?")
        case .moveAllToTrash:
            return String(localized: "Move All to Trash?")
        case .emptyTrash:
            return String(localized: "Empty Trash?")
        case .deleteSelected:
            return directory == .trash
                ? String(localized: "Delete Selected?")
                : String(localized: "Move Selected to Trash?")
        case .none:
            return String(localized: "Move to Trash?")
        }
    }

    private var confirmationButtonTitle: LocalizedStringKey {
        switch pendingDeletion {
        case .moveToTrash, .moveAllToTrash, .deleteSelected:
            return directory == .trash ? "Delete Permanently" : "Move to Trash"
        case .deletePermanently:
            return "Delete Permanently"
        case .emptyTrash:
            return "Empty Trash"
        case .none:
            return "Delete"
        }
    }

    private var confirmationMessage: String {
        switch pendingDeletion {
        case .moveToTrash(let file):
            if file.isDirectory {
                let count = library.fileCount(in: file.url)
                if count > 0 {
                    return String(
                        format: String(localized: "%@ · This will also move %ld files inside the folder to Trash."),
                        file.name,
                        count
                    )
                }
            }
            return file.name
        case .deletePermanently(let file):
            return "\(file.name) · \(String(localized: "This cannot be undone."))"
        case .moveAllToTrash:
            return String(localized: "All files will be moved to Trash.")
        case .emptyTrash:
            return String(localized: "All files will be permanently deleted.")
        case .deleteSelected:
            return String(format: String(localized: "%ld files selected"), selectedPaths.count)
        case .none:
            return ""
        }
    }

    private var isAllSelected: Bool {
        !filteredFiles.isEmpty && selectedPaths.count == filteredFiles.count
    }

    private func toggleSelectAll() {
        if isAllSelected {
            selectedPaths.removeAll()
        } else {
            selectedPaths = Set(filteredFiles.map(\.url))
        }
    }

    private func toggleSelection() {
        isSelecting.toggle()
        if !isSelecting {
            selectedPaths.removeAll()
        }
    }

    private func beginRename(_ file: FileItem) {
        renameText = file.name
        renameTarget = file
    }

    private func performRename() {
        guard let target = renameTarget else { return }

        do {
            let destination = try library.rename(target, to: renameText)
            RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL)
                .updatePathPrefix(from: target.url, to: destination)
            renameTarget = nil
            Task { await reload() }
            onChanged()
        } catch {
            renameTarget = nil
            errorMessage = message(for: error)
        }
    }

    private var selectedFiles: [FileItem] {
        files.filter { selectedPaths.contains($0.url) && !$0.isDirectory }
    }

    private func dropFiles(_ urls: [URL], into folder: FileItem) -> Bool {
        var moved = false

        for url in urls {
            let item = FileItem(url: url)
            guard !item.isDirectory else { continue }

            guard item.url.deletingLastPathComponent().standardizedFileURL.path
                != folder.url.standardizedFileURL.path else {
                continue
            }

            do {
                let destination = try library.move(item, to: folder.url)
                updateRecentPath(from: item.url, to: destination)
                moved = true
            } catch {
                errorMessage = message(for: error)
            }
        }

        if moved {
            Task { await reload() }
            onChanged()
        }
        return moved
    }

    private func moveBatch(_ files: [FileItem], to targetURL: URL?) {
        guard let targetURL else {
            batchMoveRequest = nil
            return
        }

        var moved = false

        for file in files {
            guard file.url.deletingLastPathComponent().standardizedFileURL.path
                != targetURL.standardizedFileURL.path else {
                continue
            }

            do {
                let destination = try library.move(file, to: targetURL)
                updateRecentPath(from: file.url, to: destination)
                moved = true
            } catch {
                errorMessage = message(for: error)
            }
        }

        batchMoveRequest = nil
        selectedPaths.removeAll()
        isSelecting = false

        if moved {
            Task { await reload() }
            onChanged()
        }
    }

    private func updateRecentPath(from oldURL: URL, to newURL: URL) {
        RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL)
            .updatePath(from: oldURL, to: newURL)
    }

    private func createFolder() {
        guard let currentURL else { return }

        do {
            _ = try library.createDirectory(named: newFolderName, in: currentURL)
            showNewFolderAlert = false
            Task { await reload() }
            onChanged()
        } catch {
            showNewFolderAlert = false
            errorMessage = message(for: error)
        }
    }

    private func beginMove(_ file: FileItem) {
        moveTargets = library.folders(in: directory)
        movingFile = file
    }

    private func moveToRoot(_ file: FileItem) {
        guard let rootURL = library.directoryURL(for: directory) else { return }

        guard file.url.deletingLastPathComponent().standardizedFileURL.path
            != rootURL.standardizedFileURL.path else {
            movingFile = nil
            return
        }

        do {
            let destination = try library.move(file, to: rootURL)
            updateRecentPath(from: file.url, to: destination)
            movingFile = nil
            Task { await reload() }
            onChanged()
        } catch {
            movingFile = nil
            errorMessage = message(for: error)
        }
    }

    private func moveToFolder(_ file: FileItem, target: FileItem) {
        guard file.url.deletingLastPathComponent().standardizedFileURL.path
            != target.url.standardizedFileURL.path else {
            movingFile = nil
            return
        }

        do {
            let destination = try library.move(file, to: target.url)
            updateRecentPath(from: file.url, to: destination)
            movingFile = nil
            Task { await reload() }
            onChanged()
        } catch {
            movingFile = nil
            errorMessage = message(for: error)
        }
    }

    private func copy(_ file: FileItem) {
        do {
            _ = try library.copy(file)
            Task { await reload() }
            onChanged()
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func move(_ file: FileItem, to target: LibraryDirectory) {
        do {
            _ = try library.move(file, to: target)
            Task { await reload() }
            onChanged()
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func confirmDeletion() {
        guard let deletion = pendingDeletion else { return }

        do {
            switch deletion {
            case .moveToTrash(let file):
                if let destination = try library.moveToTrash(file, from: directory) {
                    updateRecentPath(from: file.url, to: destination)
                }
            case .deletePermanently(let file):
                try library.deletePermanently(file)
                RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL).remove(file.url)
            case .moveAllToTrash:
                try library.moveAllToTrash(from: directory)
            case .emptyTrash:
                try library.emptyTrash()
            case .deleteSelected:
                for path in selectedPaths {
                    guard let file = files.first(where: { $0.url == path }) else { continue }

                    if directory == .trash {
                        try library.deletePermanently(file)
                        RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL).remove(file.url)
                    } else if let destination = try library.moveToTrash(file, from: directory) {
                        updateRecentPath(from: file.url, to: destination)
                    }
                }
                selectedPaths.removeAll()
                isSelecting = false
            }
            pendingDeletion = nil
            Task { await reload() }
            onChanged()
        } catch {
            pendingDeletion = nil
            errorMessage = message(for: error)
        }
    }

    private func restoreSelected() {
        do {
            for path in selectedPaths {
                guard let file = files.first(where: { $0.url == path }) else { continue }
                if let restoredURL = try library.restore(file) {
                    updateRecentPath(from: file.url, to: restoredURL)
                    downloadManager.migrateOrigin(
                        from: file.name,
                        to: restoredURL.lastPathComponent
                    )
                }
            }
            selectedPaths.removeAll()
            isSelecting = false
            Task { await reload() }
            onChanged()
        } catch {
            errorMessage = message(for: error)
        }
    }

    private func restore(_ file: FileItem) {
        do {
            if let restoredURL = try library.restore(file) {
                updateRecentPath(from: file.url, to: restoredURL)
                downloadManager.migrateOrigin(
                    from: file.name,
                    to: restoredURL.lastPathComponent
                )
            }
            Task { await reload() }
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func message(for error: Error) -> String {
        if let libraryError = error as? FileLibraryError {
            switch libraryError {
            case .invalidName:
                return String(localized: "The file name is not valid.")
            case .storageUnavailable:
                return String(localized: "Storage is unavailable.")
            case .invalidEncoding:
                return String(localized: "The selected encoding is not supported.")
            }
        }
        return error.localizedDescription
    }

    private func pasteClipboardURL() {
        let pasteboard = UIPasteboard.general

        if let url = pasteboard.url?.absoluteString {
            downloadURL = url
            return
        }

        if let string = pasteboard.string {
            downloadURL = extractURL(from: string) ?? string
        }
    }

    private func extractURL(from string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s"'<>]+"#) else {
            return nil
        }

        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range),
              let matchRange = Range(match.range, in: string) else {
            return nil
        }

        return String(string[matchRange])
    }

    private func resolveURL() {
        if let extracted = extractURL(from: downloadURL) {
            downloadURL = extracted
        }

        isResolvingURL = true
        downloadError = nil
        let urlString = downloadURL

        Task {
            let suggested = await downloadManager.resolveSuggestedFileName(urlString: urlString)
            isResolvingURL = false

            guard let suggested else {
                downloadError = String(localized: "Invalid URL.")
                return
            }

            pendingDownloadURL = urlString
            resolvedFileName = suggested
            downloadStep = .fileName
        }
    }

    private func startDownload() {
        guard downloadManager.start(
            urlString: pendingDownloadURL,
            fileName: resolvedFileName
        ) else {
            downloadError = String(localized: "Invalid URL.")
            return
        }

        downloadStep = .url
        downloadURL = ""
        resolvedFileName = ""
        pendingDownloadURL = ""
        downloadError = nil
        showDownloadSheet = false
    }

    private func reload() async {
        if directory == .trash {
            let days = UserDefaults.standard.integer(forKey: "settings.trashAutoClearDays")
            if days > 0 {
                _ = try? await Task.detached {
                    try FileLibrary().clearExpiredTrash(olderThan: days)
                }.value
            }
        }

        let loaded = await Task.detached { [library, directory, folderURL] in
            if let folderURL {
                return library.contents(at: folderURL)
            }
            return library.files(in: directory)
        }.value
        files = loaded
    }
}

private struct FileListRow: View {
    let file: FileItem
    let now: Date

    @AppStorage("settings.relativeTime") private var relativeTime = true

    var body: some View {
        HStack(spacing: 12) {
            FileThumbnailView(file: file, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)

                Text(fileDetailText(for: file, relativeTime: relativeTime, now: now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FileGridCell: View {
    let file: FileItem
    let now: Date

    @AppStorage("settings.relativeTime") private var relativeTime = true

    var body: some View {
        VStack(spacing: 6) {
            FileThumbnailView(file: file, size: 64)

            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(fileDetailText(for: file, relativeTime: relativeTime, now: now))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SystemDirectory: Identifiable {
    var id: String { title }

    let title: String
    let systemImage: String
    let color: Color
    let itemCount: Int
    let directory: LibraryDirectory
    var subtitle: String? = nil
}

struct DirectoryRow: View {
    let directory: SystemDirectory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: directory.systemImage)
                .font(.title3)
                .foregroundStyle(directory.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(directory.title))

                if let subtitle = directory.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(directory.itemCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 固定英文单位（B / KB / MB / GB），避免跟随系统语言显示「字节」。
private func fileDetailText(for file: FileItem, relativeTime: Bool, now: Date) -> String {
    if file.isDirectory {
        return String(localized: "Folder")
    }

    var parts: [String] = []

    if FileLibrary.rootDirectory(for: file.url) == .trash,
       let source = FileLibrary.trashSource(for: file.url) {
        parts.append(source.localizedTitle)
    }

    if let size = file.size {
        parts.append(formattedFileSize(size))
    }
    if let date = file.modifiedAt {
        parts.append(
            relativeTime
                ? relativeTimeText(for: date, now: now)
                : date.formatted(date: .abbreviated, time: .shortened)
        )
    }

    return parts.joined(separator: " · ")
}


private enum InboxSortField: String {
    case name
    case date
    case size
    case added
}

private enum ViewMode: String {
    case list
    case grid
}

private enum Deletion {
    case moveToTrash(FileItem)
    case deletePermanently(FileItem)
    case moveAllToTrash
    case emptyTrash
    case deleteSelected
}


private struct DownloadRow: View {
    let task: DownloadTask
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusSymbol)
                    .font(.title3)
                    .foregroundStyle(statusColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.fileName)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                actionButton
            }

            if task.status == .downloading || task.status == .pending {
                ProgressView(value: task.progress)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusSymbol: String {
        switch task.status {
        case .pending:
            return "clock"
        case .downloading:
            return "arrow.down.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        case .cancelled:
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .secondary
        default:
            return .blue
        }
    }

    private var subtitle: String {
        switch task.status {
        case .downloading, .pending:
            let percent = Int(task.progress * 100)
            let current = formattedFileSize(task.bytesWritten)
            let total = task.totalBytes > 0
                ? formattedFileSize(task.totalBytes)
                : String(localized: "Unknown")
            return "\(percent)% · \(current) / \(total)"
        case .completed:
            return formattedFileSize(task.bytesWritten)
        case .failed:
            return task.errorMessage ?? String(localized: "Failed")
        case .cancelled:
            return String(localized: "Cancelled")
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch task.status {
        case .downloading, .pending:
            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .font(.caption)
        case .failed, .cancelled:
            HStack(spacing: 8) {
                Button("Retry") {
                    onRetry()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Button("Remove") {
                    onRemove()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        case .completed:
            Button("Remove") {
                onRemove()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private enum DownloadStep {
    case url
    case fileName
}

private struct SharedLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MountedFolder: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
}

private struct BatchMoveRequest: Identifiable {
    let id = UUID()
    let files: [FileItem]
}
