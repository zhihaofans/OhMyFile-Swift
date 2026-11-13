//
//  FilePreviewView.swift
//  OhMyFile
//
//  统一预览入口：文本只读、其余 QuickLook、不支持的类型给出提示。
//

import OSLog
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct FilePreviewView: View {
    let file: FileItem
    var recordsRecent = true

    private var capability: FileCapability {
        FileCapabilityResolver.capability(for: file.url)
    }

    private var structuredKind: StructuredKind? {
        let type = capability.contentType
        if type.conforms(to: .json) {
            return .json
        }
        if type.conforms(to: .xml) {
            return .xml
        }

        switch file.url.pathExtension.lowercased() {
        case "json":
            return .json
        case "xml", "plist":
            return .xml
        default:
            return nil
        }
    }

    private var isHTML: Bool {
        if capability.contentType.conforms(to: .html) {
            return true
        }
        return ["html", "htm"].contains(file.url.pathExtension.lowercased())
    }

    private var isCSV: Bool {
        if capability.contentType.conforms(to: .commaSeparatedText) {
            return true
        }
        return ["csv", "tsv"].contains(file.url.pathExtension.lowercased())
    }

    private var isMarkdown: Bool {
        let markdownType = UTType("net.daringfireball.markdown")
        if let markdownType, capability.contentType.conforms(to: markdownType) {
            return true
        }
        return ["md", "markdown", "mdown", "mkd"].contains(file.url.pathExtension.lowercased())
    }

    private var shouldUseQuickLook: Bool {
        // .bin 被系统识别为 MacBinary 归档，QuickLook 会显示「拷贝到」界面，不提供预览。
        if file.url.pathExtension.lowercased() == "bin" {
            return false
        }

        return QLPreviewController.canPreview(file.url as NSURL)
    }

    private var isText: Bool {
        let type = capability.contentType
        return type.conforms(to: .text)
            || type.conforms(to: .json)
            || type.conforms(to: .xml)
    }

    var body: some View {
        Group {
            if let structuredKind {
                StructuredPreviewView(file: file, kind: structuredKind)
            } else if isHTML {
                HTMLPreviewView(file: file)
            } else if isCSV {
                CSVPreviewView(file: file)
            } else if isMarkdown {
                MarkdownPreviewView(file: file)
            } else if let codeLanguage = CodeLanguage.detect(for: file.url) {
                CodePreviewView(file: file, language: codeLanguage)
            } else if isText {
                TextPreviewView(file: file)
            } else if shouldUseQuickLook {
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
                ShareFileButton(fileURL: file.url)
            }
        }
        .onAppear {
            AppLog.preview.info("preview opened: \(file.name, privacy: .public)")
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
