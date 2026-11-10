//
//  SearchableText.swift
//  OhMyFile
//
//  只读可选中文本视图：搜索高亮、跳转当前匹配、匹配计数（不区分大小写）。
//

import SwiftUI
import UIKit

struct SearchableText: UIViewRepresentable {
    let text: String
    let query: String
    let currentMatch: Int
    let font: UIFont
    let colorScheme: ColorScheme
    let onMatchCountChange: (Int) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.textContainer.widthTracksTextView = true
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let matches = SearchMatcher.matches(in: text, query: query)
        let current = matches.isEmpty ? 0 : min(max(0, currentMatch), matches.count - 1)

        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.label
            ]
        )

        let currentColor: UIColor = colorScheme == .dark
            ? UIColor.systemOrange.withAlphaComponent(0.45)
            : UIColor.systemOrange.withAlphaComponent(0.5)
        let matchColor: UIColor = colorScheme == .dark
            ? UIColor.systemYellow.withAlphaComponent(0.22)
            : UIColor.systemYellow.withAlphaComponent(0.35)

        for (index, range) in matches.enumerated() {
            attributed.addAttribute(
                .backgroundColor,
                value: index == current ? currentColor : matchColor,
                range: range
            )
        }

        textView.attributedText = attributed

        if !matches.isEmpty {
            textView.scrollRangeToVisible(matches[current])
        }

        let count = matches.count
        DispatchQueue.main.async {
            onMatchCountChange(count)
        }
    }
}

enum SearchMatcher {
    nonisolated static func matches(in text: String, query: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }

        let nsText = text as NSString
        var ranges: [NSRange] = []
        var location = 0

        while location < nsText.length {
            let range = nsText.range(
                of: query,
                options: [.caseInsensitive],
                range: NSRange(location: location, length: nsText.length - location)
            )

            guard range.location != NSNotFound else { break }

            ranges.append(range)
            location = range.location + max(range.length, 1)
        }

        return ranges
    }
}
