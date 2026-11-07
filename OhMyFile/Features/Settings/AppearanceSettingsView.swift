//
//  AppearanceSettingsView.swift
//  OhMyFile
//
//  设置 → 外观：配色方案 + 浅色 / 暗黑强调色。
//

import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("settings.appearance") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("settings.lightAccent") private var lightAccentHex = AccentColorStorage.defaultLightHex
    @AppStorage("settings.darkAccent") private var darkAccentHex = AccentColorStorage.defaultDarkHex

    private var lightBinding: Binding<Color> {
        Binding(
            get: { AccentColorStorage.color(from: lightAccentHex) },
            set: { lightAccentHex = AccentColorStorage.hex(from: $0) }
        )
    }

    private var darkBinding: Binding<Color> {
        Binding(
            get: { AccentColorStorage.color(from: darkAccentHex) },
            set: { darkAccentHex = AccentColorStorage.hex(from: $0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Text(label(for: mode)).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("Accent Color") {
                ColorPicker("Light", selection: lightBinding, supportsOpacity: false)
                ColorPicker("Dark", selection: darkBinding, supportsOpacity: false)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for mode: AppearanceMode) -> LocalizedStringKey {
        switch mode {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}
