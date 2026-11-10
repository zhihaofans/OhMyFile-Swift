//
//  SearchBarView.swift
//  OhMyFile
//
//  预览内容搜索条：输入、结果计数、上一个 / 下一个、关闭。
//

import SwiftUI

struct SearchBarView: View {
    @Binding var query: String
    let matchCount: Int
    let currentIndex: Int
    var showsNavigation = true
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    onSubmit?()
                }

            if !query.isEmpty {
                Text(
                    matchCount == 0
                        ? String(localized: "No Results")
                        : "\(currentIndex + 1)/\(matchCount)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }

            if showsNavigation {
                Button {
                    onPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(matchCount == 0)

                Button {
                    onNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(matchCount == 0)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
