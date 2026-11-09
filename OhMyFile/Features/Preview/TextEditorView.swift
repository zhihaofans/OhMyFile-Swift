//
//  TextEditorView.swift
//  OhMyFile
//
//  纯文本编辑：保存前确认覆盖，原子写入，失败不破坏原文件。
//

import SwiftUI

struct TextEditorView: View {
    let file: FileItem
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: String
    @State private var originalText: String
    @State private var isSaving = false
    @State private var showSavedNotice = false
    @State private var activeAlert: EditorAlert?

    init(file: FileItem, text: String, onSaved: @escaping () -> Void) {
        self.file = file
        self.onSaved = onSaved
        _draft = State(initialValue: text)
        _originalText = State(initialValue: text)
    }

    private var hasChanges: Bool {
        draft != originalText
    }

    var body: some View {
        TextEditor(text: $draft)
            .font(.system(.body, design: .monospaced))
            .padding()
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            activeAlert = .discard
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareFileButton(fileURL: file.url)
                        .disabled(hasChanges || isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        activeAlert = .save
                    }
                    .disabled(!hasChanges || isSaving)
                }
            }
            .overlay(alignment: .top) {
                if showSavedNotice {
                    Text("Saved")
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .save:
                    return Alert(
                        title: Text("Save and overwrite the original file?"),
                        primaryButton: .default(Text("Save")) {
                            save()
                        },
                        secondaryButton: .cancel()
                    )
                case .discard:
                    return Alert(
                        title: Text("Unsaved Changes"),
                        message: Text("Discard changes?"),
                        primaryButton: .destructive(Text("Discard")) {
                            dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                case .error(let message):
                    return Alert(
                        title: Text("Error"),
                        message: Text(message),
                        dismissButton: .cancel(Text("OK"))
                    )
                }
            }
    }

    private func save() {
        isSaving = true

        Task {
            do {
                guard let data = draft.data(using: .utf8) else {
                    isSaving = false
                    activeAlert = .error(String(localized: "Unable to save the file."))
                    return
                }

                let url = file.url
                try await Task.detached {
                    try AtomicFileWriter.write(data, to: url)
                }.value

                originalText = draft
                isSaving = false
                onSaved()
                showSavedNotice = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    showSavedNotice = false
                }
            } catch {
                isSaving = false
                activeAlert = .error(String(localized: "Unable to save the file."))
            }
        }
    }
}

private enum EditorAlert: Identifiable {
    case save
    case discard
    case error(String)

    var id: String {
        switch self {
        case .save:
            return "save"
        case .discard:
            return "discard"
        case .error(let message):
            return "error-\(message)"
        }
    }
}
