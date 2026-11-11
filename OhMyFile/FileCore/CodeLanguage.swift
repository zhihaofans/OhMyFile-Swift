//
//  CodeLanguage.swift
//  OhMyFile
//
//  代码语言识别与轻量词法规则；纯内核代码。
//

import Foundation

nonisolated enum CodeLanguage {
    case swift
    case kotlin
    case java
    case javascript
    case typescript
    case python
    case css
    case cFamily
    case shell
    case go
    case rust
    case ruby
    case php

    nonisolated static func detect(for url: URL) -> CodeLanguage? {
        switch url.pathExtension.lowercased() {
        case "swift":
            return .swift
        case "kt", "kts":
            return .kotlin
        case "java":
            return .java
        case "js", "mjs", "cjs", "jsx":
            return .javascript
        case "ts", "tsx", "mts", "cts":
            return .typescript
        case "py", "pyi":
            return .python
        case "css", "scss", "less":
            return .css
        case "c", "h", "cpp", "cc", "cxx", "hpp", "m", "mm":
            return .cFamily
        case "sh", "bash", "zsh":
            return .shell
        case "go":
            return .go
        case "rs":
            return .rust
        case "rb":
            return .ruby
        case "php":
            return .php
        default:
            return nil
        }
    }

    var lineComment: String? {
        switch self {
        case .python, .ruby, .shell:
            return "#"
        case .swift, .kotlin, .java, .javascript, .typescript, .cFamily, .go, .rust, .php:
            return "//"
        case .css:
            return nil
        }
    }

    var supportsBlockComment: Bool {
        switch self {
        case .python, .ruby, .shell:
            return false
        default:
            return true
        }
    }

    var keywordSet: Set<String> {
        switch self {
        case .swift:
            return [
                "func", "let", "var", "if", "else", "guard", "for", "while", "repeat",
                "switch", "case", "default", "return", "break", "continue", "fallthrough",
                "class", "struct", "enum", "protocol", "extension", "import", "typealias",
                "associatedtype", "init", "deinit", "self", "super", "static", "final",
                "override", "open", "public", "private", "fileprivate", "internal",
                "mutating", "nonmutating", "convenience", "required", "lazy", "weak",
                "unowned", "async", "await", "throws", "throw", "try", "catch", "defer",
                "in", "where", "is", "as", "some", "any", "nil", "true", "false",
                "operator", "subscript", "inout", "indirect"
            ]
        case .kotlin:
            return [
                "fun", "val", "var", "if", "else", "when", "for", "while", "do",
                "return", "break", "continue", "class", "object", "interface", "data",
                "sealed", "enum", "annotation", "import", "package", "typealias", "init",
                "constructor", "companion", "this", "super", "null", "true", "false",
                "override", "open", "abstract", "private", "protected", "public",
                "internal", "lateinit", "const", "suspend", "inline", "noinline",
                "crossinline", "reified", "by", "get", "set", "where", "in", "is",
                "as", "out", "vararg"
            ]
        case .java:
            return [
                "abstract", "assert", "boolean", "break", "byte", "case", "catch",
                "char", "class", "const", "continue", "default", "do", "double",
                "else", "enum", "extends", "final", "finally", "float", "for", "if",
                "implements", "import", "instanceof", "int", "interface", "long",
                "native", "new", "package", "private", "protected", "public", "return",
                "short", "static", "strictfp", "super", "switch", "synchronized",
                "this", "throw", "throws", "transient", "try", "void", "volatile",
                "while", "true", "false", "null", "var", "record", "sealed", "permits",
                "yield"
            ]
        case .javascript:
            return [
                "var", "let", "const", "function", "return", "if", "else", "for",
                "while", "do", "switch", "case", "default", "break", "continue",
                "class", "extends", "new", "this", "super", "import", "export",
                "from", "async", "await", "try", "catch", "finally", "throw",
                "typeof", "instanceof", "in", "of", "delete", "void", "yield",
                "true", "false", "null", "undefined", "static", "get", "set"
            ]
        case .typescript:
            return [
                "var", "let", "const", "function", "return", "if", "else", "for",
                "while", "do", "switch", "case", "default", "break", "continue",
                "class", "extends", "new", "this", "super", "import", "export",
                "from", "async", "await", "try", "catch", "finally", "throw",
                "typeof", "instanceof", "in", "of", "delete", "void", "yield",
                "true", "false", "null", "undefined", "static", "get", "set",
                "interface", "type", "enum", "namespace", "declare", "abstract",
                "implements", "public", "private", "protected", "readonly", "as",
                "keyof", "infer", "never", "unknown", "any", "string", "number",
                "boolean", "symbol", "bigint", "object", "satisfies"
            ]
        case .python:
            return [
                "def", "class", "if", "elif", "else", "for", "while", "return",
                "import", "from", "as", "try", "except", "finally", "raise", "with",
                "lambda", "yield", "global", "nonlocal", "assert", "del", "pass",
                "break", "continue", "and", "or", "not", "in", "is", "True", "False",
                "None", "async", "await", "match", "case", "self"
            ]
        case .css:
            return []
        case .cFamily:
            return [
                "int", "char", "float", "double", "void", "long", "short", "unsigned",
                "signed", "const", "static", "extern", "struct", "union", "enum",
                "typedef", "if", "else", "for", "while", "do", "switch", "case",
                "default", "break", "continue", "return", "goto", "sizeof",
                "volatile", "register", "inline", "class", "public", "private",
                "protected", "virtual", "override", "new", "delete", "namespace",
                "using", "template", "typename", "auto", "nullptr", "true", "false",
                "try", "catch", "throw"
            ]
        case .shell:
            return [
                "if", "then", "else", "elif", "fi", "for", "while", "do", "done",
                "case", "esac", "function", "in", "return", "exit", "export",
                "local", "readonly", "echo", "cd", "ls", "rm", "mkdir", "cp", "mv",
                "cat", "grep", "awk", "sed"
            ]
        case .go:
            return [
                "func", "package", "import", "var", "const", "type", "struct",
                "interface", "map", "chan", "go", "defer", "select", "case",
                "default", "if", "else", "for", "range", "switch", "return",
                "break", "continue", "fallthrough", "goto", "nil", "true", "false",
                "make", "new", "len", "cap", "append", "copy", "delete", "panic",
                "recover"
            ]
        case .rust:
            return [
                "fn", "let", "mut", "const", "static", "struct", "enum", "trait",
                "impl", "for", "while", "loop", "if", "else", "match", "return",
                "break", "continue", "use", "mod", "pub", "crate", "self", "Self",
                "super", "as", "in", "where", "async", "await", "move", "ref",
                "dyn", "type", "unsafe", "extern", "true", "false", "Some", "None",
                "Ok", "Err"
            ]
        case .ruby:
            return [
                "def", "class", "module", "if", "elsif", "else", "unless", "while",
                "until", "for", "in", "do", "end", "begin", "rescue", "ensure",
                "raise", "return", "break", "next", "redo", "retry", "yield",
                "super", "self", "nil", "true", "false", "and", "or", "not",
                "require", "include", "extend", "attr_accessor", "attr_reader",
                "attr_writer"
            ]
        case .php:
            return [
                "function", "class", "interface", "trait", "extends", "implements",
                "public", "private", "protected", "static", "const", "var", "if",
                "else", "elseif", "for", "foreach", "while", "do", "switch", "case",
                "default", "break", "continue", "return", "require", "include",
                "require_once", "include_once", "new", "echo", "print", "true",
                "false", "null", "try", "catch", "finally", "throw", "namespace",
                "use", "as"
            ]
        }
    }
}
