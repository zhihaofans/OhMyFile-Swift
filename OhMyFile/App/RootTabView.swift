//
//  RootTabView.swift
//  OhMyFile
//
//  应用主导航：文件 / 最近 / 设置。
//

import CrashKit
import OSLog
import SwiftUI

struct RootTabView: View {
    @AppStorage("settings.appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("settings.lightAccent") private var lightAccentHex = AccentColorStorage.defaultLightHex
    @AppStorage("settings.darkAccent") private var darkAccentHex = AccentColorStorage.defaultDarkHex

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: MainTab
    @State private var launchDirectory: LibraryDirectory?
    @State private var shareRefreshToken = UUID()
    @State private var openInboxToken = UUID()
    @State private var openedExternalFile: ExternalFileRequest?
    @State private var openFileAlert: OpenFileAlert?
    @State private var isImporting = false
    @State private var lockController = AppLockController()
    @State private var crashReport: CrashReport?

    @AppStorage("settings.crashReportsEnabled") private var crashReportsEnabled = true

    init() {
        let raw = UserDefaults.standard.string(forKey: "settings.launchPage")
            ?? LaunchPage.files.rawValue
        let page = LaunchPage(rawValue: raw) ?? .files

        _selectedTab = State(initialValue: page.mainTab)
        _launchDirectory = State(initialValue: page.directory)
    }

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    private var tintColor: Color {
        colorScheme == .dark
            ? AccentColorStorage.color(from: darkAccentHex)
            : AccentColorStorage.color(from: lightAccentHex)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            FilesView(
                refreshToken: shareRefreshToken,
                openInboxToken: openInboxToken,
                initialDirectory: launchDirectory
            )
                .tabItem { Label("Files", systemImage: "folder.fill") }
                .tag(MainTab.files)

            RecentView()
                .tabItem { Label("Recent", systemImage: "clock.fill") }
                .tag(MainTab.recent)

            SettingsView(lockController: lockController)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(MainTab.settings)
        }
        .preferredColorScheme(appearance.colorScheme)
        .tint(tintColor)
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
        .alert(
            crashReport?.title ?? String(localized: "Crash Report"),
            isPresented: Binding(
                get: { crashReport != nil },
                set: { if !$0 { crashReport = nil } }
            )
        ) {
            Button("OK", role: .cancel) { crashReport = nil }
        } message: {
            Text(crashReport?.details ?? "")
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
        .overlay {
            if lockController.isLocked {
                LockScreenView(controller: lockController)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                lockController.lock()
            } else if phase == .active {
                consumePendingImport()
            }
        }
        .task {
            consumePendingImport()
            checkCrashReport()
        }
    }

    private func checkCrashReport() {
        guard crashReportsEnabled else {
            _ = CrashRecorder.shared.takePendingReport()
            return
        }

        crashReport = CrashRecorder.shared.takePendingReport()
    }

    private func consumePendingImport() {
        Task {
            // 给分享扩展写入 App Group UserDefaults 留出同步时间。
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard let defaults = UserDefaults(suiteName: "group.me.zzhhoo.OhMyFile") else { return }
            defaults.synchronize()

            let pending = defaults.integer(forKey: "pendingImportCount")
            guard pending > 0 else { return }

            defaults.set(0, forKey: "pendingImportCount")
            defaults.synchronize()
            selectedTab = .files
            shareRefreshToken = UUID()
            openInboxToken = UUID()
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
                    let nsError = error as NSError
                    AppLog.imports.error("import failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
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

enum LaunchPage: String, CaseIterable {
    case settings
    case recent
    case files
    case inbox
    case downloads
    case trash

    var mainTab: MainTab {
        switch self {
        case .settings:
            return .settings
        case .recent:
            return .recent
        default:
            return .files
        }
    }

    var directory: LibraryDirectory? {
        switch self {
        case .inbox:
            return .inbox
        case .downloads:
            return .downloads
        case .trash:
            return .trash
        default:
            return nil
        }
    }
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

enum MainTab: Hashable {
    case files
    case recent
    case settings
}
