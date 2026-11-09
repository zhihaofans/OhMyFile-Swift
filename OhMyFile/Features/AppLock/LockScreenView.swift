//
//  LockScreenView.swift
//  OhMyFile
//
//  应用锁解锁界面：6 位密码 + Face ID / Touch ID。
//

import LocalAuthentication
import SwiftUI

struct LockScreenView: View {
    let controller: AppLockController

    @State private var pin = ""
    @State private var errorMessage: String?
    @State private var isAuthenticating = false
    @FocusState private var isPinFocused: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("AppIconPreview")
                    .resizable()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

                Text("OhMyFile")
                    .font(.title2.bold())

                Text("Enter Passcode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("Passcode", text: $pin)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isPinFocused)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .frame(width: 180)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: pin) { _, newValue in
                        if newValue.count > 6 {
                            pin = String(newValue.prefix(6))
                        }
                        if newValue.count == 6 {
                            unlock()
                        }
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Unlock") {
                    unlock()
                }
                .buttonStyle(.borderedProminent)
                .disabled(pin.count != 6)

                if controller.isBiometricAvailable {
                    Button {
                        authenticate()
                    } label: {
                        Label(
                            String(
                                format: String(localized: "Unlock with %@"),
                                controller.biometricLabel
                            ),
                            systemImage: biometricSymbol
                        )
                    }
                    .disabled(isAuthenticating)
                }
            }
            .padding(24)
        }
        .onAppear {
            isPinFocused = true
        }
    }

    private var biometricSymbol: String {
        switch controller.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.open"
        }
    }

    private func unlock() {
        guard pin.count == 6 else {
            errorMessage = String(localized: "Enter a 6-digit passcode.")
            return
        }

        if controller.unlock(pin: pin) {
            pin = ""
            errorMessage = nil
        } else {
            pin = ""
            errorMessage = String(localized: "Incorrect passcode.")
        }
    }

    private func authenticate() {
        isAuthenticating = true

        Task {
            let success = await controller.authenticateWithBiometrics()
            isAuthenticating = false

            if !success {
                errorMessage = String(localized: "Face ID / Touch ID failed. Enter your passcode.")
            }
        }
    }
}
