//
//  RootTabView.swift
//  OhMyFile
//
//  应用主导航：文件 / 最近 / 设置。
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            FilesView()
                .tabItem { Label("Files", systemImage: "folder.fill") }

            RecentView()
                .tabItem { Label("Recent", systemImage: "clock.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
