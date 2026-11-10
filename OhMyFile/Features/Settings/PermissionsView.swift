//
//  PermissionsView.swift
//  OhMyFile
//
//  权限管理：显示相机 / 麦克风授权状态与用途，跳转系统设置修改。
//

import AVFoundation
import LocalAuthentication
import SwiftUI
import UIKit

struct PermissionsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var microphoneStatus: AVAudioApplication.recordPermission = .undetermined
    @State private var biometricAvailable = false
    @State private var biometricType: LABiometryType = .none

    var body: some View {
        List {
            Section {
                permissionRow(
                    title: "Camera",
                    icon: "camera.fill",
                    color: .blue,
                    status: cameraStatusText,
                    statusColor: cameraStatusColor,
                    purpose: "Take photos and scan documents."
                )

                permissionRow(
                    title: "Microphone",
                    icon: "mic.fill",
                    color: .red,
                    status: microphoneStatusText,
                    statusColor: microphoneStatusColor,
                    purpose: "Record audio when capturing video."
                )
            }

            Section {
                permissionRow(
                    title: biometricTitle,
                    icon: biometricIcon,
                    color: .green,
                    status: biometricAvailable
                        ? String(localized: "Supported")
                        : String(localized: "Not Supported"),
                    statusColor: biometricAvailable ? .green : .secondary,
                    purpose: "Used to unlock OhMyFile when App Lock is enabled."
                )
            } footer: {
                Text("Face ID / Touch ID is managed by system settings.")
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Open Settings") {
                    openSettings()
                }
            }
        }
        .task { refresh() }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refresh()
            }
        }
    }

    private func permissionRow(
        title: String,
        icon: String,
        color: Color,
        status: String,
        statusColor: Color,
        purpose: String
    ) -> some View {
        Button {
            openSettings()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color, in: RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(LocalizedStringKey(title))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(status)
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }

                    Text(LocalizedStringKey(purpose))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func refresh() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVAudioApplication.shared.recordPermission

        let context = LAContext()
        var error: NSError?
        biometricAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        biometricType = biometricAvailable ? context.biometryType : .none
    }

    private var biometricTitle: String {
        guard biometricAvailable else {
            return String(localized: "Biometrics")
        }

        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        default:
            return String(localized: "Biometrics")
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .touchID:
            return "touchid"
        default:
            return "faceid"
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private var cameraStatusText: String {
        switch cameraStatus {
        case .authorized:
            return String(localized: "Authorized")
        case .denied:
            return String(localized: "Denied")
        case .restricted:
            return String(localized: "Restricted")
        case .notDetermined:
            return String(localized: "Not Requested")
        @unknown default:
            return String(localized: "Not Requested")
        }
    }

    private var cameraStatusColor: Color {
        switch cameraStatus {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .secondary
        }
    }

    private var microphoneStatusText: String {
        switch microphoneStatus {
        case .granted:
            return String(localized: "Authorized")
        case .denied:
            return String(localized: "Denied")
        case .undetermined:
            return String(localized: "Not Requested")
        @unknown default:
            return String(localized: "Not Requested")
        }
    }

    private var microphoneStatusColor: Color {
        switch microphoneStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        default:
            return .secondary
        }
    }
}
