//
//  FileInfoView.swift
//  OhMyFile
//
//  文件信息：名称、类型、大小、时间、路径、来源，可复制。
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FileInfoView: View {
    let file: FileItem

    @Environment(\.dismiss) private var dismiss

    private var contentType: UTType {
        FileCapabilityResolver.contentType(for: file.url)
    }

    private var typeText: String {
        contentType.localizedDescription ?? file.url.pathExtension.uppercased()
    }

    private var displayPath: String {
        if let directory = FileLibrary.rootDirectory(for: file.url) {
            var path = directory.localizedTitle

            if let sub = FileLibrary.relativeDirectoryPath(for: file.url, in: directory),
               !sub.isEmpty {
                path += "/" + sub
            }

            return path + "/" + file.name
        }

        return file.url.path
    }

    private var sourceText: String? {
        if let origin = DownloadManager.shared.originURL(for: file.url) {
            return origin.absoluteString
        }

        if FileLibrary.rootDirectory(for: file.url) == nil {
            return String(localized: "External")
        }

        return nil
    }

    private var summary: String {
        var lines: [String] = []
        lines.append("\(String(localized: "Name")): \(file.name)")
        lines.append("\(String(localized: "Type")): \(typeText)")

        if !file.isDirectory, let size = file.size {
            lines.append("\(String(localized: "Size")): \(formattedFileSize(size))")
        }
        if let importedAt = file.importedAt {
            lines.append("\(String(localized: "Imported")): \(importedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let modifiedAt = file.modifiedAt {
            lines.append("\(String(localized: "Modified")): \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let deletedAt = file.deletedAt {
            lines.append("\(String(localized: "Deleted")): \(deletedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        lines.append("\(String(localized: "Path")): \(displayPath)")

        if let sourceText {
            lines.append("\(String(localized: "Source")): \(sourceText)")
        }

        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        FileThumbnailView(file: file, size: 56)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(file.name)
                                .font(.headline)

                            Text(typeText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    LabeledContent("Type", value: typeText)

                    if file.isDirectory {
                        LabeledContent("Size", value: String(localized: "Folder"))
                    } else if let size = file.size {
                        LabeledContent("Size", value: formattedFileSize(size))
                    }

                    if let importedAt = file.importedAt {
                        LabeledContent(
                            "Imported",
                            value: importedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }

                    if let modifiedAt = file.modifiedAt {
                        LabeledContent(
                            "Modified",
                            value: modifiedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }

                    if let deletedAt = file.deletedAt {
                        LabeledContent(
                            "Deleted",
                            value: deletedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }

                Section("Path") {
                    Text(displayPath)
                        .font(.footnote)
                        .textSelection(.enabled)
                }

                if let sourceText {
                    Section("Source") {
                        Text(sourceText)
                            .font(.footnote)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = summary
                    } label: {
                        Label("Copy Info", systemImage: "doc.on.doc")
                    }
                }
            }
            .navigationTitle("File Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
