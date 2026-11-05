//
//  FilesView.swift
//  OhMyFile
//
//  文件页：收件箱 / 下载 / 回收站目录 + 文件列表空状态。
//

import SwiftUI

struct FilesView: View {
    @State private var searchText = ""

    private let directories: [SystemDirectory] = [
        SystemDirectory(title: "Inbox", systemImage: "tray.fill", color: .blue, itemCount: 0),
        SystemDirectory(title: "Downloads", systemImage: "arrow.down.circle.fill", color: .purple, itemCount: 0),
        SystemDirectory(title: "Trash", systemImage: "trash.fill", color: .green, itemCount: 0)
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(directories) { directory in
                        NavigationLink {
                            DirectoryView(directory: directory)
                        } label: {
                            DirectoryRow(directory: directory)
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
