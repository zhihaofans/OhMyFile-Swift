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

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isPreparingEdit = false
    @State private var editError: String?
    @State private var previewRefreshToken = UUID()

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

    private func prepareEdit() {
        isPreparingEdit = true

        Task {
            do {
                try await CloudFileDownloader.ensureDownloaded(at: file.url)
                editText = try await Task.detached {
                    try TextFileLoader.load(url: file.url)
                }.value
                isPreparingEdit = false
                isEditing = true
            } catch {
                isPreparingEdit = false
                editError = textLoadingMessage(for: error)
            }
        }
    }

    private var shouldUseQuickLook: Bool {
        // .bin 被系统识别为 MacBinary 归档，QuickLook 会显示「拷贝到」界面，不提供预览。
        if file.url.pathExtension.lowercased() == "bin" {
            return false
        }

        return QLPreviewController.canPreview(file.url as NSURL)
    }

    private var isZip: Bool {
        capability.contentType.conforms(to: .zip) || file.url.pathExtension.lowercased() == "zip"
    }

    private var isText: Bool {
        let type = capability.contentType
        return type.conforms(to: .text)
            || type.conforms(to: .json)
            || type.conforms(to: .xml)
    }

    private var canEditText: Bool {
        // txt / Markdown / JSON / XML / CSV 已有各自的编辑入口；这里补齐 HTML 与代码文件。
        isHTML || CodeLanguage.detect(for: file.url) != nil
    }

    var body: some View {
        Group {
            if isZip {
                ZipBrowserView(file: file)
            } else if let structuredKind {
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
        .id(previewRefreshToken)
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEditText {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareEdit()
                    } label: {
                        if isPreparingEdit {
                            ProgressView()
                        } else {
                            Image(systemName: "pencil")
                        }
                    }
                    .disabled(isPreparingEdit)
                    .accessibilityLabel("Edit")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareFileButton(fileURL: file.url)
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                TextEditorView(file: file, text: editText) {
                    previewRefreshToken = UUID()
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { editError != nil },
                set: { if !$0 { editError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(editError ?? "")
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
