//
//  NewFileView.swift
//  OhMyFile
//
//  新建文本文件：文件名、扩展名、位置、编码、换行、模板。
//

import SwiftUI

struct NewFileView: View {
    let directory: LibraryDirectory
    let folderURL: URL?
    let onCreated: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var fileName = ""
    @State private var fileExtension = "txt"
    @State private var encodingRaw = "utf8"
    @State private var lineEndingRaw = TextLineEnding.lf.rawValue
    @State private var templateRaw = "blank"
    @State private var errorMessage: String?

    private let library = FileLibrary()

    private let extensions = [
        "txt", "md", "html", "json", "xml", "csv", "css", "js", "swift", "kt", "java", "py"
    ]

    private var parentURL: URL? {
        folderURL ?? library.directoryURL(for: directory)
    }

    private var selectedEncoding: String.Encoding {
        switch encodingRaw {
        case "utf16":
            return .utf16
        case "gb18030":
            return String.Encoding(rawValue: 0x80000632)
        default:
            return .utf8
        }
    }

    private var selectedLineEnding: TextLineEnding {
        TextLineEnding(rawValue: lineEndingRaw) ?? .lf
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("File name", text: $fileName)

                    Picker("Extension", selection: $fileExtension) {
                        ForEach(extensions, id: \.self) { ext in
                            Text(".\(ext)").tag(ext)
                        }
                    }
                }

                Section("Location") {
                    Text(parentURL?.lastPathComponent ?? directory.localizedTitle)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Encoding", selection: $encodingRaw) {
                        Text("UTF-8").tag("utf8")
                        Text("UTF-16").tag("utf16")
                        Text("GB18030").tag("gb18030")
                    }

                    Picker("Line Endings", selection: $lineEndingRaw) {
                        Text("LF").tag(TextLineEnding.lf.rawValue)
                        Text("CRLF").tag(TextLineEnding.crlf.rawValue)
                        Text("CR").tag(TextLineEnding.cr.rawValue)
                    }

                    Picker("Template", selection: $templateRaw) {
                        Text("Blank").tag("blank")
                        Text("Sample").tag("sample")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        create()
                    }
                    .disabled(fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        guard let parentURL else {
            errorMessage = String(localized: "Storage is unavailable.")
            return
        }

        do {
            let template = templateRaw == "sample"
                ? String(localized: "Sample text") + "\n"
                : ""

            let url = try library.createTextFile(
                named: fileName,
                extension: fileExtension,
                in: parentURL,
                encoding: selectedEncoding,
                lineEnding: selectedLineEnding,
                template: template
            )

            onCreated(url)
            dismiss()
        } catch FileLibraryError.invalidName {
            errorMessage = String(localized: "The file name is not valid.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
