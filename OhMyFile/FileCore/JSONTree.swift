//
//  JSONTree.swift
//  OhMyFile
//
//  JSON 解析为可折叠节点树；纯内核代码。
//

import CoreFoundation
import Foundation

nonisolated enum JSONValue: Equatable {
    case object
    case array
    case string(String)
    case number(String)
    case bool(Bool)
    case null
}

nonisolated struct JSONNode: Identifiable, Equatable {
    let id: String
    let key: String?
    let value: JSONValue
    let children: [JSONNode]?
}

enum JSONTreeParser {
    nonisolated static func parse(_ text: String) throws -> JSONNode {
        let data = Data(text.utf8)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        return node(from: object, key: nil, path: "$")
    }

    private nonisolated static func node(from value: Any, key: String?, path: String) -> JSONNode {
        if let dictionary = value as? [String: Any] {
            let children = dictionary.keys.sorted().map { childKey in
                node(from: dictionary[childKey] as Any, key: childKey, path: "\(path).\(childKey)")
            }
            return JSONNode(id: path, key: key, value: .object, children: children)
        }

        if let array = value as? [Any] {
            let children = array.enumerated().map { index, child in
                node(from: child, key: "[\(index)]", path: "\(path)[\(index)]")
            }
            return JSONNode(id: path, key: key, value: .array, children: children)
        }

        if let string = value as? String {
            return JSONNode(id: path, key: key, value: .string(string), children: nil)
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return JSONNode(id: path, key: key, value: .bool(number.boolValue), children: nil)
            }
            return JSONNode(id: path, key: key, value: .number(number.stringValue), children: nil)
        }

        return JSONNode(id: path, key: key, value: .null, children: nil)
    }
}
