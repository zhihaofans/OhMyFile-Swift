//
//  ExternalFolderView.swift
//  OhMyFile
//
//  已挂载的外部文件夹浏览（只读）。
//

import SwiftUI

struct ExternalFolderView: View {
    let folder: MountedFolder
    let url: URL

    @State private var files: [FileItem] = []
    @State private var isPreparing = true
    @State private var errorMessage: String?
    @State private var previewItem: ExternalPreviewItem?

    var body: some View {
        Group {
            if isPreparing {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if files.isEmpty {
                ContentUnavailableView(
                    "Folder is Empty",
                    systemImage: "folder",
                    description: Text("Files in this folder will appear here.")
                )
            } else {
                List {
                    ForEach(files) { file in
                        if file.isDirectory {
                            NavigationLink {
                                ExternalFolderView(folder: folder, url: file.url)
                            } label: {
                                FileListRow(file: file, now: Date())
                            }
                        } else {
                            Button {
                                previewItem = ExternalPreviewItem(url: file.url)
                            } label: {
                                FileListRow(file: file, now: Date())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(folder.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .sheet(item: $previewItem) { item in
            ExternalFilePreviewView(url: item.url)
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

    private func load() async {
        let accessing = url.startAccessingSecurityScopedResource()

        let loaded = await Task.detached { [url] in
            (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: .skipsHiddenFiles
            ).map(FileItem.init(url:))) ?? []
        }.value

        if accessing {
            url.stopAccessingSecurityScopedResource()
        }

        files = loaded.sorted {
            ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast)
        }
        isPreparing = false
    }
}

private struct ExternalPreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}
