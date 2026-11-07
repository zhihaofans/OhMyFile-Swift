//
//  ClipboardImportSheet.swift
//  OhMyFile
//
//  剪贴板导入：先显示加载状态，读取完成后编辑文件名并写入收件箱。
//

import SwiftUI

struct ClipboardImportSheet: View {
    let onImported: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var loaded: ClipboardImport?
    @State private var fileName = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Reading Clipboard…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loaded {
                    Form {
                        Section {
                            TextField("File name", text: $fileName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            LabeledContent("Size", value: formattedFileSize(contentSize(loaded.content)))
                        }

                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Clipboard is Empty",
                        systemImage: "doc.on.clipboard"
                    )
                }
            }
            .navigationTitle("Import from Clipboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importFile()
                    }
                    .disabled(loaded == nil || fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .task {
            await load()
        }
        .onDisappear {
            cleanupTemporaryFile()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let result = await ClipboardReader.load() else {
            loaded = nil
            return
        }

        fileName = FileLibrary().availableFileName(
            in: .inbox,
            preferredName: result.defaultFileName
        )
        loaded = result
    }

    private func importFile() {
        guard let loaded else { return }

        do {
            switch loaded.content {
            case .data(let data):
                _ = try FileLibrary().importData(data, fileName: fileName)
            case .file(let url, _):
                _ = try FileLibrary().importFile(from: url, fileName: fileName)
            }
            onImported()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func contentSize(_ content: ClipboardContent) -> Int64 {
        switch content {
        case .data(let data):
            return Int64(data.count)
        case .file(let url, _):
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return Int64(size)
        }
    }

    private func cleanupTemporaryFile() {
        guard case .file(let url, let isTemporary)? = loaded?.content, isTemporary else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
