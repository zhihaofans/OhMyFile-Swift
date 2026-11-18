//
//  LanTransferView.swift
//  OhMyFile
//
//  局域网 / 热点文件传输：用户显式开启后电脑浏览器可上传 / 下载。
//

import OSLog
import SwiftUI
import UIKit

struct LanTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var isRunning = false
    @State private var session: LanTransferSession?
    @State private var errorMessage: String?
    @State private var server = LanTransferServer()
    @AppStorage("settings.lanTransferPort") private var lanTransferPort = 8080

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Start Server", isOn: $isRunning)
                        .onChange(of: isRunning) { _, running in
                            if running {
                                start()
                            } else {
                                stop()
                            }
                        }
                } footer: {
                    Text("Only works while this page is open. Files are shared on the local network.")
                }

                if let session {
                    Section("Address") {
                        Text(session.address)
                            .font(.body.monospaced())
                            .textSelection(.enabled)

                        Button {
                            UIPasteboard.general.string = session.address
                        } label: {
                            Label("Copy Address", systemImage: "doc.on.doc")
                        }
                    }

                    Section {
                        Text("Open the address in a browser on a computer connected to the same Wi-Fi or hotspot.")
                    }
                }
            }
            .navigationTitle("LAN Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onDisappear {
                stop()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    stop()
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func start() {
        errorMessage = nil

        Task {
            do {
                let port = UInt16(min(max(lanTransferPort, 1), 65535))
                session = try await server.start(port: port)
            } catch {
                isRunning = false
                session = nil
                errorMessage = message(for: error)
                AppLog.lan.error("server start failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func stop() {
        server.stop()
        session = nil
        isRunning = false
    }

    private func message(for error: Error) -> String {
        switch error as? LanTransferError {
        case .noLocalAddress:
            return String(localized: "Connect to Wi-Fi or enable a hotspot first.")
        case .startFailed:
            return String(localized: "Failed to start the server.")
        case .portUnavailable:
            return String(localized: "Port is already in use.")
        case nil:
            return error.localizedDescription
        }
    }
}
