//
//  SettingsView.swift
//  OhMyFile
//
//  设置页：外观、存储空间、相对时间、语言（跳系统设置）、版本。
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("settings.relativeTime") private var relativeTime = true

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
                }

                Section("Files") {
                    Toggle(isOn: $relativeTime) {
                        SettingsLabel(title: "Relative Time", systemImage: "clock.arrow.circlepath", color: .orange)
                    }
                }

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Text("About")

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
