//
//  DocumentScanner.swift
//  OhMyFile
//
//  VisionKit 文档扫描：多页、自动裁边；取消不产生文件。
//

import SwiftUI
import UIKit
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScanner

        init(parent: DocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []

            for index in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }

            parent.onScan(images)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.dismiss()
        }
    }
}

enum ScannedPDF {
    static func make(from images: [UIImage]) -> Data? {
        guard let first = images.first else { return nil }

        let bounds = CGRect(origin: .zero, size: first.size)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { context in
            for image in images {
                context.beginPage()

                let pageBounds = context.pdfContextBounds
                let scale = min(
                    pageBounds.width / image.size.width,
                    pageBounds.height / image.size.height
                )
                let size = CGSize(
                    width: image.size.width * scale,
                    height: image.size.height * scale
                )
                let origin = CGPoint(
                    x: (pageBounds.width - size.width) / 2,
                    y: (pageBounds.height - size.height) / 2
                )

                image.draw(in: CGRect(origin: origin, size: size))
            }
        }
    }
}
