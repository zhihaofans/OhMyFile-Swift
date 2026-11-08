//
//  TextPreviewView.swift
//  OhMyFile
//
//  只读文本预览，UTF-8，单文件上限 2 MB。
//

import SwiftUI

struct TextPreviewView: View {
    let file: FileItem

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isEditing = false

    private var canEdit: Bool {
        file.url.pathExtension.lowercased() == "txt"
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
            } else if let text {
                ScrollView {
                    Text(verbatim: text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "Unable to Read File",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "")
                )
            }
        }
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .disabled(text == nil)
                    .accessibilityLabel("Edit")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                TextEditorView(file: file, text: text ?? "") {
                    Task { await load() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true

        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
            errorMessage = nil
        } catch {
            text = nil
            errorMessage = textLoadingMessage(for: error)
        }

        isLoading = false
    }

}
