//
//  CodePreviewView.swift
//  OhMyFile
//
//  代码只读预览：行号 + 等宽字体 + 语法高亮 + 字号调节；不自动换行。
//

import SwiftUI

struct CodePreviewView: View {
    let file: FileItem
    let language: CodeLanguage

    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("code.fontSize") private var fontSize = 14.0
    @AppStorage("settings.codeTheme") private var themeRaw = CodeTheme.xcode.id

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

    private let maxLines = 20_000

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
            } else if let text {
                codeView(text)
            } else {
                ContentUnavailableView(
                    "Unable to Read File",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage ?? "")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Font Size", selection: $fontSize) {
                        Text("Small").tag(12.0)
                        Text("Medium").tag(14.0)
                        Text("Large").tag(17.0)
                    }
                } label: {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .task { await load() }
    }

    private func codeView(_ text: String) -> some View {
        let allLines = text.components(separatedBy: "\n")
        let truncated = allLines.count > maxLines
        let shownText = truncated
            ? allLines.prefix(maxLines).joined(separator: "\n")
            : text
        let lineCount = max(shownText.components(separatedBy: "\n").count, 1)
        let lineNumbers = (1...lineCount).map(String.init).joined(separator: "\n")
        let attributed = highlight(shownText)

        return ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 6) {
                if truncated {
                    Text(String(format: String(localized: "Showing first %ld lines"), maxLines))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 12)
                }

                HStack(alignment: .top, spacing: 0) {
                    Text(lineNumbers)
                        .font(.system(size: fontSize, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .padding(.leading, 12)
                        .padding(.trailing, 12)

                    Text(attributed)
                        .font(.system(size: fontSize, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, 16)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func highlight(_ text: String) -> AttributedString {
        var result = AttributedString()
        let nsText = text as NSString
        var cursor = 0

        for highlight in CodeHighlighter.highlights(in: text, language: language) {
            guard highlight.range.location >= cursor else { continue }

            if highlight.range.location > cursor {
                let prefix = nsText.substring(
                    with: NSRange(location: cursor, length: highlight.range.location - cursor)
                )
                result += AttributedString(prefix)
            }

            let token = nsText.substring(with: highlight.range)
            var piece = AttributedString(token)
            piece.foregroundColor = color(for: highlight.kind)
            result += piece

            cursor = highlight.range.location + highlight.range.length
        }

        if cursor < nsText.length {
            result += AttributedString(nsText.substring(from: cursor))
        }

        return result
    }

    private var theme: CodeTheme {
        CodeTheme.theme(for: themeRaw)
    }

    private func color(for kind: CodeTokenKind) -> Color {
        theme.color(for: kind, colorScheme: colorScheme)
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
