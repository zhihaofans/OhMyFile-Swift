//
//  RootTabView.swift
//  OhMyFile
//
//  应用主导航：文件 / 最近 / 设置。
//

import SwiftUI

struct RootTabView: View {
    @State private var selectedTab: MainTab = .files
    @State private var shareRefreshToken = UUID()
    @State private var openInboxToken = UUID()
    @State private var openedExternalFile: ExternalFileRequest?
    @State private var openFileAlert: OpenFileAlert?
    @State private var isImporting = false

    var body: some View {
        TabView(selection: $selectedTab) {
            FilesView(refreshToken: shareRefreshToken, openInboxToken: openInboxToken)
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(MainTab.files)

            RecentView()
                .tabItem { Label("Recent", systemImage: "clock.fill") }
                .tag(MainTab.recent)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(MainTab.settings)
        }
        .onOpenURL { url in
            if url.isFileURL {
                handleOpenFile(url)
            } else if url.scheme == "ohmyfile" {
                selectedTab = .files
                shareRefreshToken = UUID()
                openInboxToken = UUID()
            }
        }
        .sheet(item: $openedExternalFile) { request in
            ExternalFilePreviewView(url: request.url)
        }
        .alert(item: $openFileAlert) { alert in
            switch alert {
            case .unsupported(let url):
                return Alert(
                    title: Text("Unsupported Format"),
                    message: Text("This file type cannot be previewed. Import it anyway?"),
                    primaryButton: .default(Text("Import")) {
                        importFile(url)
                    },
                    secondaryButton: .cancel()
                )
            case .error(let message):
                return Alert(
                    title: Text("Error"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            }
        }
        .overlay {
            if isImporting {
                ProgressView("Importing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func handleOpenFile(_ url: URL) {
        if FileCapabilityResolver.capability(for: url).canPreview {
            openedExternalFile = ExternalFileRequest(url: url)
        } else {
            openFileAlert = .unsupported(url)
        }
    }

    private func importFile(_ url: URL) {
        isImporting = true

        Task {
            let outcome = await Task.detached { () -> (URL?, String?) in
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    return (try FileLibrary().importFile(from: url), nil)
                } catch {
                    return (nil, error.localizedDescription)
                }
            }.value

            isImporting = false

            if outcome.0 != nil {
                selectedTab = .files
                shareRefreshToken = UUID()
                openInboxToken = UUID()
            } else {
                openFileAlert = .error(outcome.1 ?? "")
            }
        }
    }
}

private struct ExternalFileRequest: Identifiable {
    let url: URL
    var id: URL { url }
}

private enum OpenFileAlert: Identifiable {
    case unsupported(URL)
    case error(String)

    var id: String {
        switch self {
        case .unsupported(let url):
            return "unsupported-\(url.absoluteString)"
        case .error(let message):
            return "error-\(message)"
        }
    }
}

private enum MainTab: Hashable {
    case files
    case recent
    case settings
}
