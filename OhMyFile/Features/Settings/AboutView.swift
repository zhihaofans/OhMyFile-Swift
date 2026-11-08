//
//  AboutView.swift
//  OhMyFile
//
//  关于：版本、分享、反馈、隐私说明、致谢。
//

import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var showShareSheet = false

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
                    Image(systemName: "doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

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
