//
//  CSVPreviewView.swift
//  OhMyFile
//
//  CSV 只读表格预览；横向 / 纵向滚动，超过行数上限时提示截断。
//

import SwiftUI

struct CSVPreviewView: View {
    let file: FileItem

    @AppStorage("csv.wrapText") private var wrapText = false
    @AppStorage("csv.columnWidth") private var columnWidth = 140.0

    @State private var table: CSVTable?
    @State private var sourceText: String?
    @State private var errorMessage: String?
    @State private var isEditing = false

    var body: some View {
        Group {
            if let table {
                tableView(table)
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
                Button {
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(sourceText == nil)
                .accessibilityLabel("Edit")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Wrap Text", isOn: $wrapText)

                    Picker("Column Width", selection: $columnWidth) {
                        Text("Narrow").tag(100.0)
                        Text("Medium").tag(140.0)
                        Text("Wide").tag(200.0)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                StructuredEditorView(
                    file: file,
                    kind: .csv,
                    text: sourceText ?? ""
                ) {
                    Task { await load() }
                }
            }
        }
        .task {
            await load()
        }
    }

    private func tableView(_ table: CSVTable) -> some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                row(table.header, isHeader: true, isAlternate: false)

                ForEach(Array(table.rows.enumerated()), id: \.offset) { index, cells in
                    row(cells, isHeader: false, isAlternate: index.isMultiple(of: 2) == false)
                }

                if table.truncated {
                    Text(String(format: String(localized: "Showing first %ld rows"), table.rows.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .textSelection(.enabled)
        }
    }

    private func row(_ cells: [String], isHeader: Bool, isAlternate: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                cellText(cell, isHeader: isHeader)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
            }
        }
        .background(
            isHeader
                ? Color.secondary.opacity(0.15)
                : (isAlternate ? Color.secondary.opacity(0.05) : Color.clear)
        )
    }

    @ViewBuilder
    private func cellText(_ cell: String, isHeader: Bool) -> some View {
        if wrapText {
            Text(cell)
                .font(isHeader ? .subheadline.bold() : .subheadline)
                .frame(width: columnWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(cell)
                .font(isHeader ? .subheadline.bold() : .subheadline)
                .lineLimit(1)
                .frame(minWidth: 90, alignment: .leading)
        }
    }

    private func load() async {
        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            let text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
            sourceText = text
            table = CSVParser.parse(text)
        } catch {
            errorMessage = textLoadingMessage(for: error)
        }
    }
}
