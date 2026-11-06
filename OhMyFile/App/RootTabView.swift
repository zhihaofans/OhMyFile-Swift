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
            guard url.scheme == "ohmyfile" else { return }
            selectedTab = .files
            shareRefreshToken = UUID()
            openInboxToken = UUID()
        }
    }
}

private enum MainTab: Hashable {
    case files
    case recent
    case settings
}
