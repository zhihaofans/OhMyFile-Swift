//
//  FileThumbnailView.swift
//  OhMyFile
//
//  图片 / 视频 / PDF 显示缩略图，其他格式回退类型图标；
//  .task(id:) 在视图消失时自动取消未完成的生成。
//

import SwiftUI
import UIKit

struct FileThumbnailView: View {
    let file: FileItem
    let size: CGFloat
    var cornerRadius: CGFloat = 6

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: icon.symbol)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(icon.color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: file.url) {
            image = nil

            guard supportsThumbnail else { return }

            image = await ThumbnailService.shared.thumbnail(
                for: file.url,
                size: CGSize(width: size, height: size),
                scale: UIScreen.main.scale
            )
        }
    }

    private var supportsThumbnail: Bool {
        switch FileCategoryResolver.category(for: file.url) {
        case .image, .video, .pdf:
            return true
        default:
            return false
        }
    }

    private var icon: (symbol: String, color: Color) {
        fileIcon(for: file.url)
    }
}
