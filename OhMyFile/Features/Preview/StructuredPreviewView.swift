//
//  StructuredPreviewView.swift
//  OhMyFile
//
//  JSON / XML 只读预览：树形（可折叠、着色）与文本模式（可选中复制）。
//

import SwiftUI
import UIKit

enum StructuredKind {
    case json
    case xml
}

struct StructuredPreviewView: View {
    let file: FileItem
    let kind: StructuredKind

    @State private var text: String?
    @State private var errorMessage: String?
    @State private var showSource = false

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
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("View", selection: $showSource) {
                        Text("Tree").tag(false)
                        Text("Text").tag(true)
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

private struct JSONStructuredContent: View {
    let text: String

    @State private var root: JSONNode?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let root {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        JSONNodeView(node: root, depth: 0)
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
        .task {
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

    @State private var root: XMLNode?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let root {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        XMLNodeView(node: root, depth: 0)
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
        .task {
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

    @State private var isExpanded: Bool

    init(node: JSONNode, depth: Int) {
        self.node = node
        self.depth = depth
        _isExpanded = State(initialValue: depth < 2)
    }

    var body: some View {
        if let children = node.children {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    JSONNodeView(node: child, depth: depth + 1)
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

    @State private var isExpanded: Bool

    init(node: XMLNode, depth: Int) {
        self.node = node
        self.depth = depth
        _isExpanded = State(initialValue: depth < 2)
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
                    XMLNodeView(node: child, depth: depth + 1)
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
