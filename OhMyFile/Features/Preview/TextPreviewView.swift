//
//  TextPreviewView.swift
//  OhMyFile
//
//  只读文本预览，UTF-8，单文件上限 2 MB。
//

import SwiftUI

struct TextPreviewView: View {
    let file: InboxFile

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

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
        .task { await load() }
    }

    private func load() async {
        isLoading = true

        do {
            text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
            errorMessage = nil
        } catch {
            text = nil
            errorMessage = message(for: error)
        }

        isLoading = false
    }

    private func message(for error: Error) -> String {
        guard let loadingError = error as? TextFileLoader.LoadingError else {
            return error.localizedDescription
        }

        switch loadingError {
        case .tooLarge:
            return String(localized: "File is too large to preview.")
        case .unsupportedEncoding:
            return String(localized: "Text encoding is not supported.")
        case .readFailed:
            return String(localized: "Unable to read file.")
        }
    }
}
