//
//  HTMLPreviewView.swift
//  OhMyFile
//
//  HTML 预览：原样展示（禁 JS、阻断远程资源）与阅读模式；
//  点击链接不跳转，改为复制链接并提示。
//

import OSLog
import SwiftUI
import UIKit
import WebKit

struct HTMLPreviewView: View {
    let file: FileItem

    @AppStorage("html.showReading") private var showReading = false
    @AppStorage("html.fontSize") private var fontSizeRaw = HTMLFontSize.medium.rawValue
    @AppStorage("html.theme") private var themeRaw = HTMLReadingTheme.system.rawValue

    @State private var html: String?
    @State private var errorMessage: String?
    @State private var copiedLink: String?
    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var findFound = true

    private var fontSize: HTMLFontSize {
        HTMLFontSize(rawValue: fontSizeRaw) ?? .medium
    }

    private var theme: HTMLReadingTheme {
        HTMLReadingTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        Group {
            if let html {
                HTMLWebView(
                    html: renderedHTML(from: html),
                    searchQuery: isSearching ? searchQuery : "",
                    onLinkCopied: { link in
                        copiedLink = link
                    },
                    onFindResult: { found in
                        findFound = found
                    }
                )
                .ignoresSafeArea(edges: .bottom)
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
                    Picker("Mode", selection: $showReading) {
                        Text("Original").tag(false)
                        Text("Reading").tag(true)
                    }

                    Divider()

                    Picker("Font Size", selection: $fontSizeRaw) {
                        Text("Small").tag(HTMLFontSize.small.rawValue)
                        Text("Medium").tag(HTMLFontSize.medium.rawValue)
                        Text("Large").tag(HTMLFontSize.large.rawValue)
                    }
                    .disabled(!showReading)

                    Picker("Theme", selection: $themeRaw) {
                        Text("System").tag(HTMLReadingTheme.system.rawValue)
                        Text("Light").tag(HTMLReadingTheme.light.rawValue)
                        Text("Dark").tag(HTMLReadingTheme.dark.rawValue)
                    }
                    .disabled(!showReading)

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
        .safeAreaInset(edge: .top) {
            if isSearching {
                SearchBarView(
                    query: $searchQuery,
                    matchCount: findFound ? 1 : 0,
                    currentIndex: 0,
                    showsNavigation: false,
                    onPrevious: {},
                    onNext: {},
                    onClose: {
                        isSearching = false
                        searchQuery = ""
                        findFound = true
                    }
                )
            }
        }
        .onChange(of: searchQuery) { _, _ in
            findFound = true
        }
        .overlay(alignment: .top) {
            if copiedLink != nil {
                Text("Link Copied")
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .onTapGesture { copiedLink = nil }
                    .task(id: copiedLink) {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        copiedLink = nil
                    }
            }
        }
        .task {
            await load()
        }
    }

    private func renderedHTML(from html: String) -> String {
        let sanitized = HTMLContentExtractor.sanitize(html)

        guard showReading else {
            return sanitized
        }

        return HTMLContentExtractor.readingHTML(
            from: sanitized,
            fontSize: fontSize,
            theme: theme
        )
    }

    private func load() async {
        do {
            try await CloudFileDownloader.ensureDownloaded(at: file.url)
            html = try await Task.detached { try TextFileLoader.load(url: file.url) }.value
        } catch {
            let nsError = error as NSError
            AppLog.preview.error("load failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            errorMessage = textLoadingMessage(for: error)
        }
    }
}

private struct HTMLWebView: UIViewRepresentable {
    let html: String
    let searchQuery: String
    let onLinkCopied: (String) -> Void
    let onFindResult: (Bool) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        context.coordinator.webView = webView
        context.coordinator.load(html: html)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(html: html)
        context.coordinator.search(query: searchQuery)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkCopied: onLinkCopied, onFindResult: onFindResult)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLinkCopied: (String) -> Void
        private let onFindResult: (Bool) -> Void
        private var loadedHTML: String?
        private var currentHTML = ""
        private var lastQuery = ""
        private var searchWorkItem: DispatchWorkItem?
        private var ruleListReady = false
        private var pendingHTML: String?
        weak var webView: WKWebView?

        init(onLinkCopied: @escaping (String) -> Void, onFindResult: @escaping (Bool) -> Void) {
            self.onLinkCopied = onLinkCopied
            self.onFindResult = onFindResult
        }

        func search(query: String) {
            guard query != lastQuery else { return }
            lastQuery = query

            guard !query.isEmpty else {
                // 关闭搜索：重新加载页面以清除高亮。
                loadedHTML = nil
                load(html: currentHTML)
                return
            }

            searchWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.performFind(query: query)
            }
            searchWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }

        private func performFind(query: String) {
            guard let webView else { return }

            let configuration = WKFindConfiguration()
            configuration.caseSensitive = false
            configuration.wraps = true

            webView.find(query, configuration: configuration) { [weak self] result in
                Task { @MainActor [weak self] in
                    self?.onFindResult(result.matchFound)
                }
            }
        }

        func load(html: String) {
            currentHTML = html
            guard html != loadedHTML else { return }
            loadedHTML = html
            pendingHTML = html

            guard !ruleListReady else {
                loadPending()
                return
            }

            let rules = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "OhMyFileBlockRemote",
                encodedContentRuleList: rules
            ) { [weak self] list, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    if let list {
                        self.webView?.configuration.userContentController.add(list)
                    }

                    self.ruleListReady = true
                    self.loadPending()
                }
            }
        }

        private func loadPending() {
            guard let html = pendingHTML else { return }
            webView?.loadHTMLString(html, baseURL: nil)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIPasteboard.general.string = url.absoluteString
                onLinkCopied(url.absoluteString)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
