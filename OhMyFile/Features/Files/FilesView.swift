//
//  FilesView.swift
//  OhMyFile
//
//  文件页：收件箱（真实文件）/ 下载 / 回收站。
//

import SwiftUI

struct FilesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    @State private var inboxFiles: [InboxFile] = []

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
                                InboxView(files: inboxFiles)
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
        }
    }

    private func loadInbox() async {
        inboxFiles = await Task.detached { ImportInbox.files() }.value
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

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView(
                    "Inbox is Empty",
                    systemImage: "tray",
                    description: Text("Files shared to OhMyFile will appear here.")
                )
            } else {
                List(files) { file in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.name)

                        Text(detail(for: file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(for file: InboxFile) -> String {
        var parts: [String] = []

        if let size = file.size {
            parts.append(formattedSize(size))
        }
        if let date = file.modifiedAt {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }

        return parts.joined(separator: " · ")
    }

    /// 固定英文单位（B / KB / MB / GB），避免跟随系统语言显示「字节」。
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
