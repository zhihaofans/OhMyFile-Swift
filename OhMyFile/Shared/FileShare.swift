//
//  FileShare.swift
//  OhMyFile
//
//  分享文件前复制到临时目录并清除源 URL 扩展属性，避免属性随分享外泄。
//

import Darwin
import SwiftUI

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ShareFile {
    nonisolated static func prepare(fileURL: URL) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: tempDirectory,
                withIntermediateDirectories: true
            )

            let destination = tempDirectory.appendingPathComponent(fileURL.lastPathComponent)

            // APFS 上优先写时复制（clone），大文件也几乎不产生实际复制开销；
            // 跨卷 / 不支持时回退为普通复制。
            let cloneResult = copyfile(
                fileURL.path,
                destination.path,
                nil,
                copyfile_flags_t(COPYFILE_CLONE | COPYFILE_ALL)
            )

            if cloneResult != 0 {
                try FileManager.default.copyItem(at: fileURL, to: destination)
            }

            OriginURLStore.remove(for: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: tempDirectory)
            return nil
        }
    }

    nonisolated static func cleanup(_ shareURL: URL) {
        try? FileManager.default.removeItem(at: shareURL.deletingLastPathComponent())
    }
}

struct ShareFileButton: View {
    let fileURL: URL

    @State private var shareItem: ShareItem?

    var body: some View {
        Button {
            if let prepared = ShareFile.prepare(fileURL: fileURL) {
                shareItem = ShareItem(url: prepared)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share")
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(items: [item.url]) {
                ShareFile.cleanup(item.url)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
