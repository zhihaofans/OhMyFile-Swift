//
//  MarkdownEditorView.swift
//  OhMyFile
//
//  Markdown 编辑：源码编辑与渲染预览切换，保存前确认、原子写入。
//

import SwiftUI

struct MarkdownEditorView: View {
    let file: FileItem
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: String
    @State private var originalText: String
    @State private var isSaving = false
    @State private var isPreviewing = false
    @State private var activeAlert: MarkdownEditorAlert?

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
        Group {
            if isPreviewing {
                MarkdownContentView(text: draft, extended: false)
            } else {
                TextEditor(text: $draft)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
        }
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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPreviewing.toggle()
                } label: {
                    Image(systemName: isPreviewing ? "pencil" : "eye")
                }
                .accessibilityLabel(isPreviewing ? "Edit" : "Preview")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    activeAlert = .save
                }
                .disabled(!hasChanges || isSaving)
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
                dismiss()
            } catch {
                isSaving = false
                activeAlert = .error(String(localized: "Unable to save the file."))
            }
        }
    }
}

private enum MarkdownEditorAlert: Identifiable {
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
