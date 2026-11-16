//
//  ZipBrowserView.swift
//  OhMyFile
//
//  zip 只读浏览：像文件夹一样查看压缩包内部结构与文件列表（不解压、不预览）。
//

import SwiftUI

struct ZipBrowserView: View {
    let file: FileItem

    @State private var root: ZipFolder?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isEncrypted = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Cannot Open Archive",
                    systemImage: "doc.zipper",
                    description: Text(errorMessage)
                )
            } else if let root {
                List {
                    if isEncrypted {
                        Text("Encrypted archive: showing the file list only.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    zipFolderContent(root)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func zipFolderContent(_ folder: ZipFolder) -> some View {
        Section {
            ForEach(folder.folders) { child in
                NavigationLink {
                    ZipFolderView(folder: child)
                } label: {
                    Label(child.name, systemImage: "folder.fill")
                        .foregroundStyle(.primary)
                }
            }

            ForEach(folder.files) { entry in
                ZipEntryRow(entry: entry)
            }
        }
    }

    private func load() async {
        let archive = await Task.detached { [url = file.url] in
            Result { try ZipArchiveReader.read(url: url) }
        }.value

        switch archive {
        case .success(let zip):
            root = zip.tree()
            isEncrypted = zip.isEncrypted
        case .failure(let error):
            errorMessage = message(for: error)
        }

        isLoading = false
    }

    private func message(for error: Error) -> String {
        switch error as? ZipArchiveError {
        case .notZip, .corrupted:
            return String(localized: "The file is not a valid zip archive.")
        case .unsupportedZIP64:
            return String(localized: "ZIP64 archives are not supported yet.")
        case nil:
            return error.localizedDescription
        }
    }
}

struct ZipFolderView: View {
    let folder: ZipFolder

    var body: some View {
        List {
            ForEach(folder.folders) { child in
                NavigationLink {
                    ZipFolderView(folder: child)
                } label: {
                    Label(child.name, systemImage: "folder.fill")
                        .foregroundStyle(.primary)
                }
            }

            ForEach(folder.files) { entry in
                ZipEntryRow(entry: entry)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ZipEntryRow: View {
    let entry: ZipEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var detailText: String {
        var parts: [String] = []

        if let size = entry.size {
            parts.append(formattedFileSize(size))
        }

        if let modifiedAt = entry.modifiedAt {
            parts.append(modifiedAt.formatted(date: .abbreviated, time: .shortened))
        }

        if entry.isEncrypted {
            parts.append(String(localized: "Encrypted"))
        }

        return parts.joined(separator: " · ")
    }
}
