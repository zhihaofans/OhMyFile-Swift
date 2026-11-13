//
//  CSVPreviewView.swift
//  OhMyFile
//
//  CSV 只读表格预览；横向 / 纵向滚动，超过行数上限时提示截断。
//

import OSLog
import SwiftUI

struct CSVPreviewView: View {
    let file: FileItem

    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("csv.wrapText") private var wrapText = false
    @AppStorage("csv.columnWidth") private var columnWidth = 140.0

    @State private var table: CSVTable?
    @State private var sourceText: String?
    @State private var errorMessage: String?
    @State private var isEditing = false
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var currentMatch = 0
    @State private var matchCount = 0

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

                    Divider()

                    Button {
                        isSearching = true
                    } label: {
                        Label("Search Content", systemImage: "magnifyingglass")
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
        .onChange(of: searchQuery) { _, _ in
            currentMatch = 0
            recomputeMatches()
        }
        .task {
            await load()
        }
    }

    private func tableView(_ table: CSVTable) -> some View {
        let matches = cellMatches(in: table)

        return ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    row(
                        table.header,
                        isHeader: true,
                        isAlternate: false,
                        rowIndex: 0,
                        matches: matches
                    )
                    .id(0)

                    ForEach(Array(table.rows.enumerated()), id: \.offset) { index, cells in
                        row(
                            cells,
                            isHeader: false,
                            isAlternate: index.isMultiple(of: 2) == false,
                            rowIndex: index + 1,
                            matches: matches
                        )
                        .id(index + 1)
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
            .onChange(of: currentMatch) { _, _ in
                guard isSearching, currentMatch < matches.count else { return }

                withAnimation {
                    proxy.scrollTo(matches[currentMatch].row, anchor: .center)
                }
            }
        }
    }

    private func row(
        _ cells: [String],
        isHeader: Bool,
        isAlternate: Bool,
        rowIndex: Int,
        matches: [CellMatch]
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { columnIndex, cell in
                cellText(cell, isHeader: isHeader)
                    .background(
                        highlightColor(
                            for: CellMatch(row: rowIndex, column: columnIndex),
                            in: matches
                        )
                    )
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

    private func cellMatches(in table: CSVTable) -> [CellMatch] {
        guard isSearching, !searchQuery.isEmpty else { return [] }

        var matches: [CellMatch] = []
        let allRows = [table.header] + table.rows

        for (rowIndex, cells) in allRows.enumerated() {
            for (columnIndex, cell) in cells.enumerated() {
                if cell.localizedCaseInsensitiveContains(searchQuery) {
                    matches.append(CellMatch(row: rowIndex, column: columnIndex))
                }
            }
        }

        return matches
    }

    private func recomputeMatches() {
        guard let table, isSearching else {
            matchCount = 0
            return
        }

        matchCount = cellMatches(in: table).count
        if currentMatch >= matchCount {
            currentMatch = 0
        }
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

    private func highlightColor(for match: CellMatch, in matches: [CellMatch]) -> Color {
        guard isSearching, let index = matches.firstIndex(of: match) else { return .clear }

        if colorScheme == .dark {
            return index == currentMatch
                ? Color.orange.opacity(0.4)
                : Color.yellow.opacity(0.22)
        }

        return index == currentMatch
            ? Color.orange.opacity(0.35)
            : Color.yellow.opacity(0.35)
    }

    private func load() async {
        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            let text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
            sourceText = text
            table = CSVParser.parse(text)
        } catch {
            let nsError = error as NSError
            AppLog.preview.error("load failed: \(file.name, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            errorMessage = textLoadingMessage(for: error)
        }
    }
}

private struct CellMatch: Equatable {
    let row: Int
    let column: Int
}
