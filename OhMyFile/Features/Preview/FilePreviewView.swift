//
//  FilePreviewView.swift
//  OhMyFile
//
//  统一预览入口：文本只读、其余 QuickLook、不支持的类型给出提示。
//

import SwiftUI
import UniformTypeIdentifiers

struct FilePreviewView: View {
    let file: InboxFile

    private var capability: FileCapability {
        FileCapabilityResolver.capability(for: file.url)
    }

    private var isText: Bool {
        let type = capability.contentType
        return type.conforms(to: .text)
            || type.conforms(to: .json)
            || type.conforms(to: .xml)
            || type.conforms(to: .spreadsheet)
    }

    var body: some View {
        Group {
            if isText {
                TextPreviewView(file: file)
            } else if capability.canPreview {
                QuickLookPreview(url: file.url)
                    .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Preview Not Supported",
                    systemImage: "questionmark",
                    description: Text("This file type cannot be previewed yet.")
                )
            }
        }
        .navigationTitle(file.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
        }
    }
}
