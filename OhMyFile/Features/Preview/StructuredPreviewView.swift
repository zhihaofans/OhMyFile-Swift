//
//  StructuredPreviewView.swift
//  OhMyFile
//
//  JSON / XML 只读预览：树形（可折叠、着色）与文本模式（可选中复制）。
//

import OSLog
import SwiftUI
import UIKit

enum StructuredKind: Equatable {
    case json
    case xml
}

struct StructuredPreviewView: View {
    let file: FileItem
    let kind: StructuredKind

    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var showSource = false
    @State private var isEditing = false
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var currentMatch = 0
    @State private var matchCount = 0
    @State private var sourceBeforeSearch = false

    var body: some View {
        Group {
            if let text {
                if showSource {
                    sourceView(text)
                } else {
                    switch kind {
                    case .json:
                        JSONStructuredContent(text: text)
                    case .xml:
                        XMLStructuredContent(text: text)
                    }
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
            if kind == .xml || kind == .json {
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

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("View", selection: $showSource) {
                        Text("Tree").tag(false)
                        Text("Text").tag(true)
                    }

                    Divider()

                    Button {
                        sourceBeforeSearch = showSource
                        showSource = true
                        isSearching = true
                    } label: {
                        Label("Search Content", systemImage: "magnifyingglass")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                StructuredEditorView(
                    file: file,
                    kind: kind == .xml ? .xml : .json,
                    text: text ?? ""
                ) {
                    Task { await load() }
                }
            }
        }
        .task {
            await load()
        }
    }

    private func sourceView(_ text: String) -> some View {
        SearchableText(
            text: text,
            query: isSearching ? searchQuery : "",
            currentMatch: currentMatch,
            font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular),
            colorScheme: colorScheme,
            onMatchCountChange: { count in
                matchCount = count
                if currentMatch >= count {
                    currentMatch = 0
                }
            }
        )
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
        showSource = sourceBeforeSearch
    }

    private func load() async {
        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            text = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
        } catch {
            let nsError = error as NSError
            AppLog.preview.error("load failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            errorMessage = textLoadingMessage(for: error)
        }
    }
}

private struct JSONStructuredContent: View {
    let text: String

    @AppStorage("settings.treeCollapsedByDefault") private var collapsedByDefault = false

    @State private var root: JSONNode?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let root {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        JSONNodeView(node: root, depth: 0, collapsedByDefault: collapsedByDefault)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Invalid JSON",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: text) {
            root = nil
            errorMessage = nil

            do {
                root = try JSONTreeParser.parse(text)
            } catch {
                errorMessage = jsonErrorMessage(error)
            }
        }
    }

    private func jsonErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if let debug = nsError.userInfo["NSDebugDescription"] as? String {
            return debug
        }
        return error.localizedDescription
    }
}

private struct XMLStructuredContent: View {
    let text: String

    @AppStorage("settings.treeCollapsedByDefault") private var collapsedByDefault = false

    @State private var root: XMLNode?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let root {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        XMLNodeView(node: root, depth: 0, collapsedByDefault: collapsedByDefault)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "Invalid XML",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
            }
        }
        .task(id: text) {
            root = nil
            errorMessage = nil

            do {
                root = try XMLTreeParser.parse(text)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct JSONNodeView: View {
    let node: JSONNode
    let depth: Int
    let collapsedByDefault: Bool

    @State private var isExpanded: Bool

    init(node: JSONNode, depth: Int, collapsedByDefault: Bool) {
        self.node = node
        self.depth = depth
        self.collapsedByDefault = collapsedByDefault
        _isExpanded = State(initialValue: collapsedByDefault ? false : depth < 2)
    }

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    JSONNodeView(node: child, depth: depth + 1, collapsedByDefault: collapsedByDefault)
                }
            } label: {
                HStack(spacing: 4) {
                    keyText

                    Text(node.value == .object ? "{…}" : "[\(children.count)]")
                        .foregroundStyle(.secondary)
                }
                .font(.system(.callout, design: .monospaced))
            }
            .contextMenu {
                Button("Copy") {
                    UIPasteboard.general.string = displayText
                }
            }
        } else {
            HStack(spacing: 4) {
                keyText
                valueText
            }
            .font(.system(.callout, design: .monospaced))
            .padding(.leading, 16)
            .contextMenu {
                Button("Copy") {
                    UIPasteboard.general.string = displayText
                }
            }
        }
    }

    @ViewBuilder
    private var keyText: some View {
        if let key = node.key {
            Text(key).foregroundStyle(.blue)
            Text(":").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var valueText: some View {
        switch node.value {
        case .string(let value):
            Text("\"\(value)\"").foregroundStyle(.green)
        case .number(let value):
            Text(value).foregroundStyle(.orange)
        case .bool(let value):
            Text(value ? "true" : "false").foregroundStyle(.purple)
        case .null:
            Text("null").foregroundStyle(.secondary)
        case .object:
            Text("{…}").foregroundStyle(.secondary)
        case .array:
            Text("[…]").foregroundStyle(.secondary)
        }
    }

    private var displayText: String {
        let keyPart = node.key.map { "\($0): " } ?? ""

        switch node.value {
        case .string(let value):
            return keyPart + "\"\(value)\""
        case .number(let value):
            return keyPart + value
        case .bool(let value):
            return keyPart + (value ? "true" : "false")
        case .null:
            return keyPart + "null"
        case .object:
            return keyPart + "{…}"
        case .array:
            return keyPart + "[…]"
        }
    }
}

private struct XMLNodeView: View {
    let node: XMLNode
    let depth: Int
    let collapsedByDefault: Bool

    @State private var isExpanded: Bool

    init(node: XMLNode, depth: Int, collapsedByDefault: Bool) {
        self.node = node
        self.depth = depth
        self.collapsedByDefault = collapsedByDefault
        _isExpanded = State(initialValue: collapsedByDefault ? false : depth < 2)
    }

    var body: some View {
        if node.children.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                openTag

                if let text = node.text {
                    Text(text)
                        .padding(.leading, 12)
                }

                Text("</\(node.name)>")
                    .foregroundStyle(.blue)
            }
            .font(.system(.callout, design: .monospaced))
            .contextMenu {
                Button("Copy") {
                    UIPasteboard.general.string = displayText
                }
            }
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children) { child in
                    XMLNodeView(node: child, depth: depth + 1, collapsedByDefault: collapsedByDefault)
                }
            } label: {
                openTag
                    .font(.system(.callout, design: .monospaced))
            }
            .contextMenu {
                Button("Copy") {
                    UIPasteboard.general.string = displayText
                }
            }
        }
    }

    private var openTag: Text {
        Text("<\(node.name)\(attributeText)>")
            .foregroundStyle(.blue)
    }

    private var attributeText: String {
        node.attributes
            .sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\($0.value)\"" }
            .joined()
    }

    private var displayText: String {
        if let text = node.text {
            return "<\(node.name)\(attributeText)>\(text)</\(node.name)>"
        }
        return "<\(node.name)\(attributeText)>"
    }
}
