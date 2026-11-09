//
//  AppLockSettingsView.swift
//  OhMyFile
//
//  应用锁设置：开启 / 修改密码 / 关闭（均需验证）。
//

import SwiftUI

struct AppLockSettingsView: View {
    let controller: AppLockController

    @State private var sheetMode: PasscodeSheetMode?

    var body: some View {
        Form {
            Section {
                Toggle("App Lock", isOn: Binding(
                    get: { controller.isEnabled },
                    set: { enabled in
                        sheetMode = enabled ? .set : .disable
                    }
                ))
            }

            if controller.isEnabled {
                Section {
                    Button("Change Passcode") {
                        sheetMode = .change
                    }
                }
            }

            Section {
                HStack {
                    Text("Biometrics")

                    Spacer()

                    Text(
                        controller.isBiometricAvailable
                            ? controller.biometricLabel
                            : String(localized: "Not Available")
                    )
                    .foregroundStyle(.secondary)
                }

                Text("Forgot passcode cannot be recovered. Clearing app data is required.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("App Lock")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetMode) { mode in
            NavigationStack {
                PasscodeEntryView(mode: mode, controller: controller) {
                    sheetMode = nil
                }
            }
        }
    }
}

enum PasscodeSheetMode: String, Identifiable {
    case set
    case change
    case disable

    var id: String { rawValue }
}

private struct PasscodeEntryView: View {
    let mode: PasscodeSheetMode
    let controller: AppLockController
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentPin = ""
    @State private var newPin = ""
    @State private var confirmPin = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            if mode != .set {
                Section {
                    SecureField("Current Passcode", text: $currentPin)
                        .keyboardType(.numberPad)
                }
            }

            if mode != .disable {
                Section {
                    SecureField("New Passcode", text: $newPin)
                        .keyboardType(.numberPad)

                    SecureField("Confirm Passcode", text: $confirmPin)
                        .keyboardType(.numberPad)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(mode == .disable ? "Turn Off App Lock" : "Save") {
                    submit()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private var title: LocalizedStringKey {
        switch mode {
        case .set:
            return "Set Passcode"
        case .change:
            return "Change Passcode"
        case .disable:
            return "Turn Off App Lock"
        }
    }

    private func submit() {
        if mode != .set, !controller.verify(pin: currentPin) {
            errorMessage = String(localized: "Incorrect passcode.")
            return
        }

        if mode == .disable {
            controller.disable()
            onComplete()
            return
        }

        guard newPin.count == 6 else {
            errorMessage = String(localized: "Enter a 6-digit passcode.")
            return
        }

        guard newPin == confirmPin else {
            errorMessage = String(localized: "Passcodes do not match.")
            return
        }

        do {
            try controller.enable(pin: newPin)
            onComplete()
        } catch {
            errorMessage = String(localized: "Unable to save the passcode.")
        }
    }
}
