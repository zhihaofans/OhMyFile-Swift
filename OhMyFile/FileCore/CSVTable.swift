//
//  CSVTable.swift
//  OhMyFile
//
//  CSV 解析（RFC 4180 常用子集）：逗号分隔、双引号包裹、字段内换行、转义引号。
//  纯内核代码；超过行数上限时截断并标记。
//

import Foundation

struct CSVTable: Equatable {
    let header: [String]
    let rows: [[String]]
    let truncated: Bool
}

enum CSVParser {
    nonisolated static func parse(_ text: String, maxRows: Int = 1000) -> CSVTable {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        var index = text.startIndex

        func endField() {
            row.append(field)
            field = ""
        }

        func endRow() -> Bool {
            endField()
            rows.append(row)
            row = []
            return rows.count > maxRows
        }

        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    endField()
                case "\n", "\r\n":
                    if endRow() {
                        return makeTable(from: rows, truncated: true)
                    }
                case "\r":
                    if endRow() {
                        return makeTable(from: rows, truncated: true)
                    }
                default:
                    field.append(character)
                }
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            _ = endRow()
        }

        return makeTable(from: rows, truncated: false)
    }

    private nonisolated static func makeTable(from rows: [[String]], truncated: Bool) -> CSVTable {
        guard let first = rows.first else {
            return CSVTable(header: [], rows: [], truncated: truncated)
        }

        return CSVTable(
            header: first,
            rows: Array(rows.dropFirst()),
            truncated: truncated
        )
    }
}
