//
//  TextPreviewView.swift
//  OhMyFile
//
//  只读文本预览，UTF-8，单文件上限 2 MB；支持内容搜索。
//

import OSLog
import SwiftUI
import UIKit

struct TextPreviewView: View {
    let file: FileItem

    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var currentMatch = 0
    @State private var matchCount = 0

    private var canEdit: Bool {
        file.url.pathExtension.lowercased() == "txt"
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
            } else if let text {
                SearchableText(
                    text: text,
                    query: isSearching ? searchQuery : "",
                    currentMatch: currentMatch,
                    font: UIFont.preferredFont(forTextStyle: .callout),
                    colorScheme: colorScheme,
                    onMatchCountChange: { count in
                        matchCount = count
                        if currentMatch >= count {
                            currentMatch = 0
                        }
                    }
                )
            } else {
                ContentUnavailableView(
                    "Unable to Read File",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "")
                )
            }
        }
        .safeAreaInset(edge: .top) {
            if isSearching {
                SearchBarView(
                    query: $searchQuery,
                    matchCount: matchCount,
                    currentIndex: currentMatch,
                    onPrevious: { moveMatch(-1) },
                    onNext: { moveMatch(1) },
                    onClose: { closeSearch() },
                    onSubmit: { moveMatch(1) }
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearching = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search Content")
            }

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
        .onChange(of: searchQuery) { _, _ in
            currentMatch = 0
        }
        .task { await load() }
    }

    private func moveMatch(_ delta: Int) {
        guard matchCount > 0 else { return }
        currentMatch = (currentMatch + delta + matchCount) % matchCount
    }

    private func closeSearch() {
        isSearching = false
        searchQuery = ""
        currentMatch = 0
        matchCount = 0
    }

    private func load() async {
        isLoading = true

        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
            errorMessage = nil
        } catch {
            let nsError = error as NSError
            AppLog.preview.error("load failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            text = nil
            errorMessage = textLoadingMessage(for: error)
        }

        isLoading = false
    }

}
