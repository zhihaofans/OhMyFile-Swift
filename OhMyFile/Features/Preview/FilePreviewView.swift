//
//  FilePreviewView.swift
//  OhMyFile
//
//  统一预览入口：文本只读、其余 QuickLook、不支持的类型给出提示。
//

import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct FilePreviewView: View {
    let file: FileItem
    var recordsRecent = true

    private var capability: FileCapability {
        FileCapabilityResolver.capability(for: file.url)
    }

    private var isMarkdown: Bool {
        let markdownType = UTType("net.daringfireball.markdown")
        if let markdownType, capability.contentType.conforms(to: markdownType) {
            return true
        }
        return ["md", "markdown", "mdown", "mkd"].contains(file.url.pathExtension.lowercased())
    }

    private var isText: Bool {
        let type = capability.contentType
        return type.conforms(to: .text)
            || type.conforms(to: .json)
            || type.conforms(to: .xml)
    }

    var body: some View {
        Group {
            if isMarkdown {
                MarkdownPreviewView(file: file)
            } else if isText {
                TextPreviewView(file: file)
            } else if QLPreviewController.canPreview(file.url as NSURL) {
                QuickLookPreview(url: file.url)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Preview Not Supported",
                    systemImage: "questionmark",
                    description: Text("This file type cannot be previewed yet.")
                )
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
        .task {
            guard recordsRecent else { return }

            let url = file.url
            await Task.detached {
                RecentFilesStore.record(url)
            }.value
        }
    }
}
