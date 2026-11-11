import Foundation
import Testing
@testable import OhMyFile

struct CodeHighlighterTests {
    private func tokenTexts(in text: String, language: CodeLanguage) -> [String] {
        let highlights = CodeHighlighter.highlights(in: text, language: language)
        let nsText = text as NSString
        return highlights.map { nsText.substring(with: $0.range) }
    }

    @Test func detectsLanguages() {
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.kt")) == .kotlin)
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.java")) == .java)
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.swift")) == .swift)
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.ts")) == .typescript)
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.py")) == .python)
        #expect(CodeLanguage.detect(for: URL(fileURLWithPath: "a.txt")) == nil)
    }

    @Test func highlightsSwiftTokens() {
        let code = "let value = 42 // note\nfunc run() { print(\"hi\") }"
        let tokens = tokenTexts(in: code, language: .swift)

        #expect(tokens.contains("let"))
        #expect(tokens.contains("func"))
        #expect(tokens.contains("42"))
        #expect(tokens.contains("// note"))
        #expect(tokens.contains("\"hi\""))
    }

    @Test func highlightsIdentifiers() {
        let code = "let value = compute(42)"
        let highlights = CodeHighlighter.highlights(in: code, language: .swift)
        let nsText = code as NSString

        let identifierTokens = highlights
            .filter { $0.kind == .identifier }
            .map { nsText.substring(with: $0.range) }

        #expect(identifierTokens.contains("value"))
        #expect(identifierTokens.contains("compute"))
    }

    @Test func highlightsPythonTokens() {
        let code = "def run():\n    # comment\n    return 1"
        let tokens = tokenTexts(in: code, language: .python)

        #expect(tokens.contains("def"))
        #expect(tokens.contains("return"))
        #expect(tokens.contains("# comment"))
        #expect(tokens.contains("1"))
    }

    @Test func cssDoesNotTreatDoubleSlashAsComment() {
        let code = "a { color: red; } // not a comment"
        let tokens = tokenTexts(in: code, language: .css)

        #expect(!tokens.contains("// not a comment"))
    }

    @Test func highlightsCssBlockComment() {
        let code = "/* note */ a { color: red; }"
        let tokens = tokenTexts(in: code, language: .css)

        #expect(tokens.contains("/* note */"))
    }

    @Test func highlightsKotlinAndJavaKeywords() {
        let kotlin = tokenTexts(in: "fun main() { val x = 1 }", language: .kotlin)
        #expect(kotlin.contains("fun"))
        #expect(kotlin.contains("val"))

        let java = tokenTexts(in: "public class Main { int x = 1; }", language: .java)
        #expect(java.contains("public"))
        #expect(java.contains("class"))
        #expect(java.contains("int"))
    }
}
