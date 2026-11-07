//
//  MarkdownBlock.swift
//  OhMyFile
//
//  轻量 Markdown 块解析：基础语法 + 可选扩展（表格 / 任务列表）。
//  纯内核代码，不依赖 SwiftUI / UIKit。
//

import Foundation

nonisolated enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case listItem(text: String, ordered: Bool, number: Int?, checked: Bool?)
    case quote(String)
    case code(String, language: String?)
    case table(header: [String], rows: [[String]])
    case divider
}

enum MarkdownParser {
    nonisolated static func parse(_ text: String, extended: Bool) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)

        var index = 0
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }

                blocks.append(.code(codeLines.joined(separator: "\n"), language: language.isEmpty ? nil : language))
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if let level = headingLevel(of: trimmed) {
                flushParagraph()
                let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(level: level, text: content))
                index += 1
                continue
            }

            if isDivider(trimmed) {
                flushParagraph()
                blocks.append(.divider)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.quote(content))
                index += 1
                continue
            }

            if let item = listItem(from: line, extended: extended) {
                flushParagraph()
                blocks.append(item)
                index += 1
                continue
            }

            if extended, let table = table(from: lines, at: &index) {
                flushParagraph()
                blocks.append(table)
                continue
            }

            paragraph.append(trimmed)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    private nonisolated static func headingLevel(of line: String) -> Int? {
        var level = 0

        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }

        guard (1...6).contains(level) else { return nil }
        let rest = line.dropFirst(level)
        guard rest.first == " " else { return nil }
        return level
    }

    private nonisolated static func isDivider(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "_" }
    }

    private nonisolated static func listItem(from line: String, extended: Bool) -> MarkdownBlock? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let first = trimmed.first, ["-", "*", "+"].contains(first) {
            let rest = trimmed.dropFirst()
            guard rest.first == " " else { return nil }
            var content = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)

            var checked: Bool?
            if extended, content.hasPrefix("[ ] ") {
                checked = false
                content = String(content.dropFirst(4))
            } else if extended, content.lowercased().hasPrefix("[x] ") {
                checked = true
                content = String(content.dropFirst(4))
            }

            return .listItem(text: content, ordered: false, number: nil, checked: checked)
        }

        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty, let number = Int(digits) else { return nil }
        let rest = trimmed.dropFirst(digits.count)
        guard rest.first == ".", rest.dropFirst().first == " " else { return nil }

        let content = String(rest.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return .listItem(text: content, ordered: true, number: number, checked: nil)
    }

    private nonisolated static func table(
        from lines: [String],
        at index: inout Int
    ) -> MarkdownBlock? {
        guard index + 1 < lines.count else { return nil }

        let headerLine = lines[index]
        let separatorLine = lines[index + 1]

        guard headerLine.contains("|"), isTableSeparator(separatorLine) else { return nil }

        let header = tableCells(headerLine)
        guard !header.isEmpty else { return nil }

        var rows: [[String]] = []
        var rowIndex = index + 2

        while rowIndex < lines.count {
            let line = lines[rowIndex]
            guard line.contains("|"), !line.trimmingCharacters(in: .whitespaces).isEmpty else { break }
            rows.append(tableCells(line))
            rowIndex += 1
        }

        index = rowIndex
        return .table(header: header, rows: rows)
    }

    private nonisolated static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(line)
        guard !cells.isEmpty else { return false }

        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let withoutColons = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return !withoutColons.isEmpty && withoutColons.allSatisfy { $0 == "-" }
        }
    }

    private nonisolated static func tableCells(_ line: String) -> [String] {
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") {
            content.removeFirst()
        }
        if content.hasSuffix("|") {
            content.removeLast()
        }

        return content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
