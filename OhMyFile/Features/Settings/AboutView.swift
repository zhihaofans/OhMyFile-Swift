//
//  AboutView.swift
//  OhMyFile
//
//  关于：版本、分享、反馈、隐私说明、致谢。
//

import SwiftUI
import SwiftUtils

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var showShareSheet = false
    @State private var isExportingLogs = false
    @State private var logErrorMessage: String?
    @State private var logShareItem: ShareItem?

    private let repositoryURL = URL(string: "https://github.com/zhihaofans/OhMyFile-Swift")!
    private let issuesURL = URL(string: "https://github.com/zhihaofans/OhMyFile-Swift/issues")!

    /// 上架 App Store 后填入数字 ID，评分入口会自动出现。
    private let appStoreID = ""

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image("AppIconPreview")
                        .resizable()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))

                    Text("OhMyFile")
                        .font(.title2.bold())

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section {
                ShareLink(item: repositoryURL) {
                    Label("Share App", systemImage: "square.and.arrow.up")
                }

                Button {
                    openURL(issuesURL)
                } label: {
                    Label("Send Feedback", systemImage: "envelope")
                }

                Button {
                    exportLogs()
                } label: {
                    if isExportingLogs {
                        HStack {
                            ProgressView()
                            Text("Export Logs")
                        }
                    } else {
                        Label("Export Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }
                .disabled(isExportingLogs)

                if !appStoreID.isEmpty,
                   let reviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
                    Link(destination: reviewURL) {
                        Label("Rate on App Store", systemImage: "star")
                    }
                }
            }

            Section("Privacy") {
                Text("Files are processed locally on this device. Nothing is uploaded without your permission.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    AcknowledgementsView(repositoryURL: repositoryURL)
                } label: {
                    Label("Acknowledgements", systemImage: "heart")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logShareItem) { item in
            ActivityShareSheet(items: [item.url]) {
                try? FileManager.default.removeItem(at: item.url)
            }
            .presentationDetents([.medium, .large])
        }
        .alert(
            "Export Logs",
            isPresented: Binding(
                get: { logErrorMessage != nil },
                set: { if !$0 { logErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(logErrorMessage ?? "")
        }
    }

    private func exportLogs() {
        isExportingLogs = true

        Task {
            do {
                let text = try await LogExporter.export(
                    subsystem: AppLog.subsystem,
                    last: 3600
                )
                isExportingLogs = false

                guard !text.isEmpty else {
                    logErrorMessage = String(localized: "No logs found in the last hour.")
                    return
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                let fileName = "ohmyfile-log-\(formatter.string(from: Date())).txt"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName)

                try text.write(to: url, atomically: true, encoding: .utf8)
                logShareItem = ShareItem(url: url)
            } catch {
                isExportingLogs = false
                logErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct AcknowledgementsView: View {
    let repositoryURL: URL

    var body: some View {
        List {
            Section {
                Text("Thanks to Apple and the open-source community.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Built with SwiftUI, QuickLook, PDFKit, VisionKit, UniformTypeIdentifiers, PhotosUI and SF Symbols.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("GitHub Repository", destination: repositoryURL)
            }
        }
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
