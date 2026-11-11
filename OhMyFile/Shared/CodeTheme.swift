//
//  CodeTheme.swift
//  OhMyFile
//
//  代码高亮主题：每个 token 类型一套浅色 / 深色颜色，随系统模式自动切换。
//

import SwiftUI

struct CodeTheme: Identifiable, Equatable {
    let id: String
    let nameKey: String
    let light: [CodeTokenKind: Color]
    let dark: [CodeTokenKind: Color]

    func color(for kind: CodeTokenKind, colorScheme: ColorScheme) -> Color {
        let palette = colorScheme == .dark ? dark : light
        return palette[kind] ?? .primary
    }

    static let xcode = CodeTheme(
        id: "xcode",
        nameKey: "Xcode",
        light: [
            .keyword: Color(red: 0.68, green: 0.24, blue: 0.64),
            .string: Color(red: 0.77, green: 0.10, blue: 0.09),
            .comment: Color(red: 0.33, green: 0.40, blue: 0.47),
            .number: Color(red: 0.11, green: 0.00, blue: 0.81),
            .identifier: Color(red: 0.06, green: 0.45, blue: 0.53)
        ],
        dark: [
            .keyword: Color(red: 0.99, green: 0.37, blue: 0.64),
            .string: Color(red: 0.99, green: 0.42, blue: 0.36),
            .comment: Color(red: 0.42, green: 0.47, blue: 0.53),
            .number: Color(red: 0.82, green: 0.75, blue: 0.41),
            .identifier: Color(red: 0.40, green: 0.72, blue: 0.64)
        ]
    )

    static let all: [CodeTheme] = [.xcode]

    static func theme(for id: String) -> CodeTheme {
        all.first { $0.id == id } ?? .xcode
    }
}
