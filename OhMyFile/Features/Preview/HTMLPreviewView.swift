//
//  HTMLPreviewView.swift
//  OhMyFile
//
//  HTML 预览：原样展示（禁 JS、阻断远程资源）与阅读模式；
//  点击链接不跳转，改为复制链接并提示。
//

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

    private var fontSize: HTMLFontSize {
        HTMLFontSize(rawValue: fontSizeRaw) ?? .medium
    }

    private var theme: HTMLReadingTheme {
        HTMLReadingTheme(rawValue: themeRaw) ?? .system
    }

    var body: some View {
        Group {
            if let html {
                HTMLWebView(html: renderedHTML(from: html)) { link in
                    copiedLink = link
                }
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
            errorMessage = textLoadingMessage(for: error)
        }
    }
}

private struct HTMLWebView: UIViewRepresentable {
    let html: String
    let onLinkCopied: (String) -> Void

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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkCopied: onLinkCopied)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLinkCopied: (String) -> Void
        private var loadedHTML: String?
        private var ruleListReady = false
        private var pendingHTML: String?
        weak var webView: WKWebView?

        init(onLinkCopied: @escaping (String) -> Void) {
            self.onLinkCopied = onLinkCopied
        }

        func load(html: String) {
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
