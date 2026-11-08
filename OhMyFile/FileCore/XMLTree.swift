//
//  XMLTree.swift
//  OhMyFile
//
//  XML 解析为可折叠节点树；纯内核代码。
//

import Foundation

nonisolated struct XMLNode: Identifiable, Equatable {
    let id: String
    let name: String
    let attributes: [String: String]
    let children: [XMLNode]
    let text: String?
}

enum XMLTreeParser {
    nonisolated static func parse(_ text: String) throws -> XMLNode {
        let builder = XMLTreeBuilder()
        return try builder.parse(Data(text.utf8))
    }
}

enum XMLTreeError: Error {
    case emptyDocument
}

private nonisolated final class XMLMutableNode {
    let name: String
    let attributes: [String: String]
    var children: [XMLMutableNode] = []
    var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }
}

private nonisolated final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    private var root: XMLMutableNode?
    private var stack: [XMLMutableNode] = []
    private var parseError: Error?

    func parse(_ data: Data) throws -> XMLNode {
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw parseError ?? parser.parserError ?? XMLTreeError.emptyDocument
        }

        guard let root else {
            throw XMLTreeError.emptyDocument
        }

        return convert(root, path: root.name)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let node = XMLMutableNode(name: elementName, attributes: attributeDict)

        if let parent = stack.last {
            parent.children.append(node)
        } else {
            root = node
        }

        stack.append(node)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard let node = stack.popLast() else { return }
        node.text = node.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text += string
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    private func convert(_ node: XMLMutableNode, path: String) -> XMLNode {
        let children = node.children.enumerated().map { index, child in
            convert(child, path: "\(path)/\(child.name)[\(index)]")
        }

        return XMLNode(
            id: path,
            name: node.name,
            attributes: node.attributes,
            children: children,
            text: node.text.isEmpty ? nil : node.text
        )
    }
}
