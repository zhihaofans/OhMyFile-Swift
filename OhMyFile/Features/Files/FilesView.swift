//
//  FilesView.swift
//  OhMyFile
//
//  文件页：收件箱（真实文件）/ 下载 / 回收站。
//  排序、视图切换、清空在收件箱页的工具栏中。
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var inboxFiles: [InboxFile] = []
    @State private var importedCount = 0
    @State private var showImportAlert = false

    private var directories: [SystemDirectory] {
        [
            SystemDirectory(title: "Inbox", systemImage: "tray.fill", color: .blue, itemCount: inboxFiles.count),
            SystemDirectory(title: "Downloads", systemImage: "arrow.down.circle.fill", color: .purple, itemCount: 0),
            SystemDirectory(title: "Trash", systemImage: "trash.fill", color: .green, itemCount: 0)
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(directories) { directory in
                        if directory.title == "Inbox" {
                            NavigationLink {
                                InboxView(files: inboxFiles) {
                                    Task { await loadInbox() }
                                }
                            } label: {
                                DirectoryRow(directory: directory)
                            }
                        } else {
                            NavigationLink {
                                DirectoryView(directory: directory)
                            } label: {
                                DirectoryRow(directory: directory)
                            }
                        }
                    }
                }

                Section("Files") {
                    EmptyFilesRow()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Files")
            .searchable(text: $searchText, prompt: "Search")
            .task { await loadInbox() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await loadInbox() }
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

    private func loadInbox() async {
        inboxFiles = await Task.detached { ImportInbox.files() }.value

        let pending = await Task.detached { ImportInbox.consumePendingImportCount() }.value
        if pending > 0 {
            importedCount = pending
            showImportAlert = true
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

private struct InboxView: View {
    let files: [InboxFile]
    let onChanged: () -> Void

    @AppStorage("files.inboxSortField") private var sortFieldRaw = InboxSortField.date.rawValue
    @AppStorage("files.inboxSortAscending") private var sortAscending = false
    @AppStorage("files.viewMode") private var viewModeRaw = ViewMode.list.rawValue

    @State private var pendingDeletion: Deletion?
    @State private var errorMessage: String?

    private var viewMode: ViewMode {
        ViewMode(rawValue: viewModeRaw) ?? .list
    }

    private var sortedFiles: [InboxFile] {
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
                ContentUnavailableView(
                    "Inbox is Empty",
                    systemImage: "tray",
                    description: Text("Files shared to OhMyFile will appear here.")
                )
            } else if viewMode == .grid {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(sortedFiles) { file in
                            FileGridCell(file: file)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        pendingDeletion = .file(file)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            } else {
                List {
                    ForEach(sortedFiles) { file in
                        FileListRow(file: file)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = .file(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    pendingDeletion = .all
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(files.isEmpty)
                .accessibilityLabel("Clear Inbox")
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
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
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

    private var confirmationTitle: String {
        switch pendingDeletion {
        case .all:
            return String(localized: "Clear Inbox?")
        case .file, .none:
            return String(localized: "Delete File?")
        }
    }

    private var confirmationMessage: String {
        switch pendingDeletion {
        case .file(let file):
            return file.name
        case .all:
            return String(localized: "This cannot be undone.")
        case .none:
            return ""
        }
    }

    private func confirmDeletion() {
        guard let deletion = pendingDeletion else { return }

        do {
            switch deletion {
            case .file(let file):
                try ImportInbox.delete(file)
            case .all:
                try ImportInbox.deleteAll()
            }
            pendingDeletion = nil
            onChanged()
        } catch {
            pendingDeletion = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct FileListRow: View {
    let file: InboxFile

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
    let file: InboxFile

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

private struct DirectoryView: View {
    let directory: SystemDirectory

    var body: some View {
        ContentUnavailableView(
            LocalizedStringKey(directory.title),
            systemImage: directory.systemImage,
            description: Text("No files here yet.")
        )
        .navigationTitle(LocalizedStringKey(directory.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SystemDirectory: Identifiable {
    var id: String { title }

    let title: String
    let systemImage: String
    let color: Color
    let itemCount: Int
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
private func fileDetailText(for file: InboxFile) -> String {
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

private func fileIcon(for file: InboxFile) -> (symbol: String, color: Color) {
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
    case file(InboxFile)
    case all
}
