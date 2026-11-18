//
//  SettingsView.swift
//  OhMyFile
//
//  设置页：外观、存储空间、相对时间、语言（跳系统设置）、版本。
//

import SwiftUI
import UIKit

struct SettingsView: View {
    let lockController: AppLockController

    @Environment(\.openURL) private var openURL
    @AppStorage("settings.relativeTime") private var relativeTime = true
    @AppStorage("settings.launchPage") private var launchPageRaw = LaunchPage.files.rawValue
    @AppStorage("settings.folderPriority") private var folderPriority = false
    @AppStorage("settings.trashAutoClearDays") private var trashAutoClearDays = 0
    @AppStorage("settings.lanTransferPort") private var lanTransferPort = 8080
    @AppStorage("settings.treeCollapsedByDefault") private var treeCollapsedByDefault = false
    @AppStorage("settings.codeTheme") private var codeThemeRaw = CodeTheme.xcode.id

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
                    Toggle(isOn: $folderPriority) {
                        SettingsLabel(title: "Folders First", systemImage: "folder.fill", color: .blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            SettingsLabel(title: "Auto Clear Trash", systemImage: "trash.slash.fill", color: .red)

                            Spacer()

                            Picker("", selection: $trashAutoClearDays) {
                                Text("Off").tag(0)
                                Text("1 Day").tag(1)
                                Text("7 Days").tag(7)
                                Text("14 Days").tag(14)
                                Text("30 Days").tag(30)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        Text("Expired items are permanently deleted.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 40)
                    }

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

                Section {
                    LabeledContent {
                        TextField("8080", value: $lanTransferPort, format: .number.grouping(.never))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .onChange(of: lanTransferPort) { _, value in
                                let clamped = min(max(value, 1), 65535)
                                if clamped != value {
                                    lanTransferPort = clamped
                                }
                            }
                    } label: {
                        SettingsLabel(title: "LAN Transfer Port", systemImage: "network", color: .teal)
                    }
                } header: {
                    Text("Network")
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
