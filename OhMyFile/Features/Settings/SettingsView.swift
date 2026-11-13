//
//  SettingsView.swift
//  OhMyFile
//
//  设置页：外观、存储空间、相对时间、语言（跳系统设置）、版本。
//

import CrashKit
import SwiftUI
import UIKit

struct SettingsView: View {
    let lockController: AppLockController

    @Environment(\.openURL) private var openURL
    @AppStorage("settings.relativeTime") private var relativeTime = true
    @AppStorage("settings.launchPage") private var launchPageRaw = LaunchPage.files.rawValue
    @AppStorage("settings.treeCollapsedByDefault") private var treeCollapsedByDefault = false
    @AppStorage("settings.codeTheme") private var codeThemeRaw = CodeTheme.xcode.id
    @AppStorage("settings.crashReportsEnabled") private var crashReportsEnabled = true

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("App") {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsLabel(title: "Appearance", systemImage: "paintbrush.fill", color: .purple)
                    }

                    NavigationLink {
                        StorageView()
                    } label: {
                        SettingsLabel(title: "Storage", systemImage: "internaldrive", color: .gray)
                    }

                    NavigationLink {
                        PermissionsView()
                    } label: {
                        SettingsLabel(title: "Permissions", systemImage: "lock.shield.fill", color: .green)
                    }

                    Button {
                        openSystemSettings()
                    } label: {
                        HStack {
                            SettingsLabel(title: "Language", systemImage: "globe", color: .blue)

                            Spacer()

                            Text("System Settings")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        AppLockSettingsView(controller: lockController)
                    } label: {
                        SettingsLabel(title: "App Lock", systemImage: "lock.shield.fill", color: .green)
                    }
                }

                Section("Editor") {
                    Picker(selection: $codeThemeRaw) {
                        ForEach(CodeTheme.all) { theme in
                            Text(LocalizedStringKey(theme.nameKey)).tag(theme.id)
                        }
                    } label: {
                        SettingsLabel(title: "Highlight Theme", systemImage: "paintpalette.fill", color: .purple)
                    }

                    Toggle(isOn: $treeCollapsedByDefault) {
                        SettingsLabel(title: "Collapse Tree by Default", systemImage: "list.bullet.indent", color: .teal)
                    }
                }

                Section("Files") {
                    Picker(selection: $launchPageRaw) {
                        Text("Files").tag(LaunchPage.files.rawValue)
                        Text("Recent").tag(LaunchPage.recent.rawValue)
                        Text("Settings").tag(LaunchPage.settings.rawValue)
                        Text("Inbox").tag(LaunchPage.inbox.rawValue)
                        Text("Downloads").tag(LaunchPage.downloads.rawValue)
                        Text("Trash").tag(LaunchPage.trash.rawValue)
                    } label: {
                        SettingsLabel(title: "Launch Page", systemImage: "rectangle.on.rectangle", color: .indigo)
                    }

                    Toggle(isOn: $relativeTime) {
                        SettingsLabel(title: "Relative Time", systemImage: "clock.arrow.circlepath", color: .orange)
                    }
                }

                Section("Diagnostics") {
                    Toggle(isOn: $crashReportsEnabled) {
                        SettingsLabel(title: "Crash Reports", systemImage: "ladybug.fill", color: .orange)
                    }

                    #if DEBUG
                    Button {
                        CrashRecorder.shared.crashForTesting()
                    } label: {
                        SettingsLabel(title: "Simulate Crash", systemImage: "exclamationmark.triangle.fill", color: .red)
                    }
                    #endif
                }

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            SettingsLabel(title: "About", systemImage: "info.circle.fill", color: .gray)

                            Spacer()

                            Text("\(appVersion) (\(buildNumber))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

private struct SettingsLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
        }
    }
}
