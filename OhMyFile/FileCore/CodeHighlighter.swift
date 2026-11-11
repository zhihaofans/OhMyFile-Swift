//
//  CodeHighlighter.swift
//  OhMyFile
//
//  轻量代码词法高亮：注释 / 字符串 / 关键字 / 数字；纯内核代码。
//

import Foundation

nonisolated enum CodeTokenKind {
    case keyword
    case string
    case comment
    case number
    case identifier
}

struct CodeHighlight {
    let range: NSRange
    let kind: CodeTokenKind
}

enum CodeHighlighter {
    nonisolated static func highlights(in text: String, language: CodeLanguage) -> [CodeHighlight] {
        let nsText = text as NSString
        let length = nsText.length
        let keywords = language.keywordSet
        let lineComment = language.lineComment
        let supportsBlockComment = language.supportsBlockComment

        var highlights: [CodeHighlight] = []
        var index = 0

        while index < length {
            let character = nsText.character(at: index)

            if let lineComment, matches(nsText, at: index, string: lineComment) {
                let start = index
                while index < length, nsText.character(at: index) != 10 {
                    index += 1
                }
                highlights.append(
                    CodeHighlight(
                        range: NSRange(location: start, length: index - start),
                        kind: .comment
                    )
                )
                continue
            }

            if supportsBlockComment, matches(nsText, at: index, string: "/*") {
                let start = index
                index += 2
                while index < length - 1, !matches(nsText, at: index, string: "*/") {
                    index += 1
                }
                if index < length - 1 {
                    index += 2
                }
                highlights.append(
                    CodeHighlight(
                        range: NSRange(location: start, length: index - start),
                        kind: .comment
                    )
                )
                continue
            }

            if character == 34 || character == 39 || character == 96 {
                let start = index
                let quote = character
                index += 1

                while index < length {
                    let current = nsText.character(at: index)

                    if current == 92 {
                        index += 2
                        continue
                    }
                    if current == quote {
                        index += 1
                        break
                    }

                    index += 1
                }

                highlights.append(
                    CodeHighlight(
                        range: NSRange(location: start, length: index - start),
                        kind: .string
                    )
                )
                continue
            }

            if isDigit(character) {
                let start = index
                while index < length {
                    let current = nsText.character(at: index)
                    if isDigit(current) || current == 46 {
                        index += 1
                    } else {
                        break
                    }
                }
                highlights.append(
                    CodeHighlight(
                        range: NSRange(location: start, length: index - start),
                        kind: .number
                    )
                )
                continue
            }

            if isIdentifierStart(character) {
                let start = index
                while index < length, isIdentifierPart(nsText.character(at: index)) {
                    index += 1
                }

                let word = nsText.substring(with: NSRange(location: start, length: index - start))
                highlights.append(
                    CodeHighlight(
                        range: NSRange(location: start, length: index - start),
                        kind: keywords.contains(word) ? .keyword : .identifier
                    )
                )
                continue
            }

            index += 1
        }

        return highlights
    }

    nonisolated private static func matches(_ text: NSString, at index: Int, string: String) -> Bool {
        let length = string.utf16.count
        guard index + length <= text.length else { return false }
        return text.substring(with: NSRange(location: index, length: length)) == string
    }

    nonisolated private static func isDigit(_ character: unichar) -> Bool {
        character >= 48 && character <= 57
    }

    nonisolated private static func isIdentifierStart(_ character: unichar) -> Bool {
        (character >= 65 && character <= 90)
            || (character >= 97 && character <= 122)
            || character == 95
    }

    nonisolated private static func isIdentifierPart(_ character: unichar) -> Bool {
        isIdentifierStart(character) || isDigit(character)
    }
}
