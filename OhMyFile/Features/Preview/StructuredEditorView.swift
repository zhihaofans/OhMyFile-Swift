//
//  StructuredEditorView.swift
//  OhMyFile
//
//  XML / CSV 源码编辑：保存前校验结构，原子写入，失败不破坏原文件。
//

import SwiftUI

struct StructuredEditorView: View {
    enum Kind {
        case xml
        case csv
    }

    let file: FileItem
    let kind: Kind
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var draft: String
    @State private var originalText: String
    @State private var isSaving = false
    @State private var activeAlert: StructuredEditorAlert?

    init(file: FileItem, kind: Kind, text: String, onSaved: @escaping () -> Void) {
        self.file = file
        self.kind = kind
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let error = validationError() {
                            activeAlert = .error(error)
                        } else {
                            activeAlert = .save
                        }
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

    private func validationError() -> String? {
        switch kind {
        case .xml:
            do {
                _ = try XMLTreeParser.parse(draft)
                return nil
            } catch {
                return String(localized: "Invalid XML")
            }

        case .csv:
            let table = CSVParser.parse(draft)

            guard !table.header.isEmpty else {
                return String(localized: "CSV structure is invalid.")
            }

            let expectedColumns = table.header.count
            if table.rows.contains(where: { $0.count != expectedColumns }) {
                return String(localized: "CSV rows have different column counts.")
            }

            return nil
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

private enum StructuredEditorAlert: Identifiable {
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
