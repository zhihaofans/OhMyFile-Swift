//
//  MarkdownPreviewView.swift
//  OhMyFile
//
//  Markdown 只读阅读模式：基础语法渲染 + 可选扩展（表格 / 任务列表 / 删除线）。
//  右上角二级菜单切换「阅读 / 源码」和「扩展 Markdown」。
//

import SwiftUI

struct MarkdownPreviewView: View {
    let file: FileItem

    @AppStorage("settings.markdownExtended") private var extended = false
    @AppStorage("markdown.showSource") private var showSource = false

    @State private var text: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let text {
                if showSource {
                    sourceView(text)
                } else {
                    readingView(text)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Cannot Open File",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("View", selection: $showSource) {
                        Text("Reading").tag(false)
                        Text("Source").tag(true)
                    }

                    Divider()

                    Button {
                        extended.toggle()
                    } label: {
                        Label(
                            "Extended Markdown",
                            systemImage: extended ? "checkmark.circle.fill" : "circle"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await load()
        }
    }

    private func readingView(_ text: String) -> some View {
        let blocks = MarkdownParser.parse(text, extended: extended)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block, extended: extended)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sourceView(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }

    private func load() async {
        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
        } catch {
            errorMessage = textLoadingMessage(for: error)
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let extended: Bool

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownInline.attributed(text, extended: extended))
                .font(headingFont(level))
                .bold()

        case .paragraph(let text):
            Text(MarkdownInline.attributed(text, extended: extended))

        case .listItem(let text, let ordered, let number, let checked):
            HStack(alignment: .top, spacing: 6) {
                if let checked {
                    Image(systemName: checked ? "checkmark.square" : "square")
                        .foregroundStyle(.secondary)
                } else {
                    Text(ordered ? "\(number ?? 1)." : "•")
                        .foregroundStyle(.secondary)
                }

                Text(MarkdownInline.attributed(text, extended: extended))
            }

        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)

                Text(MarkdownInline.attributed(text, extended: extended))
                    .foregroundStyle(.secondary)
            }

        case .code(let code, let language):
            VStack(alignment: .leading, spacing: 4) {
                if let language {
                    Text(language.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

        case .table(let header, let rows):
            MarkdownTableView(header: header, rows: rows, extended: extended)

        case .divider:
            Divider()
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1:
            return .largeTitle
        case 2:
            return .title
        case 3:
            return .title2
        case 4:
            return .title3
        case 5:
            return .headline
        default:
            return .subheadline
        }
    }
}

private struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]
    let extended: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(header, bold: true)
            Divider()

            ForEach(rows.indices, id: \.self) { index in
                row(rows[index], bold: false)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ cells: [String], bold: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(MarkdownInline.attributed(cell, extended: extended))
                    .font(bold ? .subheadline.bold() : .subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// 行内 Markdown：基础用系统解析，扩展时处理 `~~删除线~~`。
private enum MarkdownInline {
    nonisolated static func attributed(_ text: String, extended: Bool) -> AttributedString {
        guard extended, text.contains("~~") else {
            return base(text)
        }

        var result = AttributedString()
        var remaining = Substring(text)

        while let open = remaining.range(of: "~~"),
              let close = remaining[open.upperBound...].range(of: "~~") {
            result += base(String(remaining[..<open.lowerBound]))

            var struck = AttributedString(String(remaining[open.upperBound..<close.lowerBound]))
            struck.strikethroughStyle = .single
            result += struck

            remaining = remaining[close.upperBound...]
        }

        result += base(String(remaining))
        return result
    }

    private nonisolated static func base(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
