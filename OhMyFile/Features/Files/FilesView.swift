//
//  FilesView.swift
//  OhMyFile
//
//  文件页：收件箱 / 下载 / 回收站。
//  删除为软删除（移入回收站），回收站可恢复或永久清空。
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    let refreshToken: UUID
    let openInboxToken: UUID

    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var counts: [LibraryDirectory: Int] = [:]
    @State private var importedCount = 0
    @State private var showImportAlert = false
    @State private var showInboxFromShare = false
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

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
                directory: .downloads
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

                    Section("Files") {
                        EmptyFilesRow()
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
                                SearchResultRow(result: result)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Files")
            .searchable(text: $searchText, prompt: "Search")
            .task { await loadCounts() }
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
                    showInboxFromShare = true
                }
            }
            .navigationDestination(isPresented: $showInboxFromShare) {
                FileListView(directory: .inbox) {
                    Task { await loadCounts() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Import from Files", systemImage: "folder") {}
                        Button("Import from Photos", systemImage: "photo") {}
                        Button("Scan Documents", systemImage: "doc.viewfinder") {}
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
            LibraryDirectory.allCases.flatMap { directory in
                library.files(in: directory)
                    .filter { $0.name.localizedStandardContains(query) }
                    .map { SearchResult(file: $0, directory: directory) }
            }
        }.value

        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon(for: result.file).symbol)
                .font(.title3)
                .foregroundStyle(fileIcon(for: result.file).color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.file.name)

                Text("\(result.directory.localizedTitle) · \(fileDetailText(for: result.file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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

private struct EmptyFilesRow: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Files Yet")
                .font(.headline)

            Text("Share files from other apps to OhMyFile, or tap + to import.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }
}

private struct FileListView: View {
    let directory: LibraryDirectory
    let onChanged: () -> Void

    @AppStorage("files.inboxSortField") private var sortFieldRaw = InboxSortField.date.rawValue
    @AppStorage("files.inboxSortAscending") private var sortAscending = false
    @AppStorage("files.viewMode") private var viewModeRaw = ViewMode.list.rawValue

    @State private var files: [FileItem] = []
    @State private var pendingDeletion: Deletion?
    @State private var errorMessage: String?

    private let library = FileLibrary()

    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRaw) ?? .list
    }

    private var sortedFiles: [FileItem] {
        let files = files
        let ascending = sortAscending

        switch InboxSortField(rawValue: sortFieldRaw) ?? .date {
        case .name:
            return files.sorted {
                let result = $0.name.localizedStandardCompare($1.name)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
        case .date:
            return files.sorted {
                let lhs = $0.modifiedAt ?? .distantPast
                let rhs = $1.modifiedAt ?? .distantPast
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .size:
            return files.sorted {
                let lhs = $0.size ?? 0
                let rhs = $1.size ?? 0
                return ascending ? lhs < rhs : lhs > rhs
            }
        }
    }

    var body: some View {
        Group {
            if files.isEmpty {
                emptyState
            } else if viewMode == .grid {
                grid
            } else {
                list
            }
        }
        .navigationTitle(titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pendingDeletion = directory == .trash ? .emptyTrash : .moveAllToTrash
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(files.isEmpty)
                .accessibilityLabel(directory == .trash ? "Empty Trash" : "Move All to Trash")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModeRaw = (viewMode == .grid ? ViewMode.list : ViewMode.grid).rawValue
                } label: {
                    Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                }
                .accessibilityLabel("Switch View")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortFieldRaw) {
                        Text("Name").tag(InboxSortField.name.rawValue)
                        Text("Date").tag(InboxSortField.date.rawValue)
                        Text("Size").tag(InboxSortField.size.rawValue)
                    }
                    Picker("Order", selection: $sortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .task { await reload() }
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
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var list: some View {
        List {
            ForEach(sortedFiles) { file in
                NavigationLink {
                    FilePreviewView(file: file)
                } label: {
                    FileListRow(file: file)
                }
                .swipeActions(edge: .trailing) {
                    trailingActions(for: file)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 12)],
                spacing: 12
            ) {
                ForEach(sortedFiles) { file in
                    NavigationLink {
                        FilePreviewView(file: file)
                    } label: {
                        FileGridCell(file: file)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        contextMenuActions(for: file)
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
        } else {
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
        case .none:
            return String(localized: "Move to Trash?")
        }
    }

    private var confirmationButtonTitle: LocalizedStringKey {
        switch pendingDeletion {
        case .moveToTrash, .moveAllToTrash:
            return "Move to Trash"
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
            return file.name
        case .deletePermanently(let file):
            return "\(file.name) · \(String(localized: "This cannot be undone."))"
        case .moveAllToTrash:
            return String(localized: "All files will be moved to Trash.")
        case .emptyTrash:
            return String(localized: "All files will be permanently deleted.")
        case .none:
            return ""
        }
    }

    private func confirmDeletion() {
        guard let deletion = pendingDeletion else { return }

        do {
            switch deletion {
            case .moveToTrash(let file):
                try library.moveToTrash(file, from: directory)
            case .deletePermanently(let file):
                try library.deletePermanently(file)
            case .moveAllToTrash:
                try library.moveAllToTrash(from: directory)
            case .emptyTrash:
                try library.emptyTrash()
            }
            pendingDeletion = nil
            Task { await reload() }
            onChanged()
        } catch {
            pendingDeletion = nil
            errorMessage = error.localizedDescription
        }
    }

    private func restore(_ file: FileItem) {
        do {
            try library.restore(file)
            Task { await reload() }
            onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async {
        let loaded = await Task.detached { [library, directory] in
            library.files(in: directory)
        }.value
        files = loaded
    }
}

private struct FileListRow: View {
    let file: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon(for: file).symbol)
                .font(.title3)
                .foregroundStyle(fileIcon(for: file).color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)

                Text(fileDetailText(for: file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct FileGridCell: View {
    let file: FileItem

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: fileIcon(for: file).symbol)
                .font(.system(size: 32))
                .foregroundStyle(fileIcon(for: file).color)
                .frame(height: 40)

            Text(file.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(fileDetailText(for: file))
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

                Text("\(directory.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 固定英文单位（B / KB / MB / GB），避免跟随系统语言显示「字节」。
private func fileDetailText(for file: FileItem) -> String {
    var parts: [String] = []

    if let size = file.size {
        parts.append(formattedSize(size))
    }
    if let date = file.modifiedAt {
        parts.append(date.formatted(date: .abbreviated, time: .shortened))
    }

    return parts.joined(separator: " · ")
}

private func formattedSize(_ bytes: Int64) -> String {
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

private func fileIcon(for file: FileItem) -> (symbol: String, color: Color) {
    let contentType = FileCapabilityResolver.contentType(for: file.url)

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

private enum InboxSortField: String {
    case name
    case date
    case size
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
}
