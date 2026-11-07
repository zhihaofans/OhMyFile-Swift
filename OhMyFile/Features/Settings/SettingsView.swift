//
//  SettingsView.swift
//  OhMyFile
//
//  设置页：当前只保留已实现的入口；未接入的板块先隐藏。
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
                        StorageView()
                    } label: {
                        SettingsLabel(title: "Storage", systemImage: "internaldrive", color: .gray)
                    }

                    Toggle(isOn: $relativeTime) {
                        SettingsLabel(title: "Relative Time", systemImage: "clock.arrow.circlepath", color: .orange)
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        SettingsLabel(title: "App Settings", systemImage: "gearshape.fill", color: .gray)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
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
