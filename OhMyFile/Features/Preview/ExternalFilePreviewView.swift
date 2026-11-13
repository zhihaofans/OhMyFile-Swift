//
//  ExternalFilePreviewView.swift
//  OhMyFile
//
//  从系统「打开方式」进入的外部文件：只预览、不自动复制。
//  点「导入」才复制到收件箱并记录最近打开；关闭未导入时不留下副本。
//

import OSLog
import SwiftUI

struct ExternalFilePreviewView: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    @State private var importedFile: FileItem?
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var accessingSecurityScope = false
    @State private var isPreparing = true

    var body: some View {
        NavigationStack {
            Group {
                if isPreparing {
                    ProgressView("Loading…")
                } else if let importedFile {
                    FilePreviewView(file: importedFile)
                } else {
                    FilePreviewView(file: FileItem(url: url), recordsRecent: false)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if importedFile == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            importFile()
                        } label: {
                            Label("Import", systemImage: "tray.and.arrow.down")
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .onAppear {
                accessingSecurityScope = url.startAccessingSecurityScopedResource()

                let store = RecentFilesStore(storageURL: RecentFilesStore.defaultStorageURL)
                let recordedURL = url
                Task.detached {
                    store.record(recordedURL, at: Date())
                }

                Task {
                    try? await CloudFileDownloader.ensureDownloaded(at: url)
                    isPreparing = false
                }
            }
            .onDisappear {
                if accessingSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                    accessingSecurityScope = false
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

    private func importFile() {
        isImporting = true

        Task {
            let outcome = await Task.detached { () -> (URL?, String?) in
                do {
                    return (try FileLibrary().importFile(from: url), nil)
                } catch {
                    let nsError = error as NSError
                    AppLog.external.error("import failed: \(url.lastPathComponent, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
                    return (nil, error.localizedDescription)
                }
            }.value

            isImporting = false

            if let importedURL = outcome.0 {
                AppLog.external.info("external import succeeded: \(url.lastPathComponent, privacy: .public)")
                importedFile = FileItem(url: importedURL)
            } else {
                errorMessage = outcome.1 ?? ""
            }
        }
    }
}
