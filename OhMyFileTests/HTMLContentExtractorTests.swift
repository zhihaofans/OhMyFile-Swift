import Foundation
import Testing
@testable import OhMyFile

struct HTMLContentExtractorTests {
    @Test func removesScriptsAndRemoteResources() {
        let html = """
        <html><body>
        <script>alert(1)</script>
        <img src="https://example.com/a.png">
        <a href="javascript:alert(1)" onclick="x()">x</a>
        <p>hello</p>
        </body></html>
        """

        let sanitized = HTMLContentExtractor.sanitize(html)

        #expect(!sanitized.contains("<script"))
        #expect(!sanitized.contains("https://example.com"))
        #expect(!sanitized.contains("javascript:"))
        #expect(!sanitized.contains("onclick"))
        #expect(sanitized.contains("hello"))
    }

    @Test func extractsArticleBody() {
        let html = """
        <html><body>
        <header>nav</header>
        <article><h1>Title</h1><p>Body text</p></article>
        <footer>footer</footer>
        </body></html>
        """

        let reading = HTMLContentExtractor.readingHTML(
            from: html,
            fontSize: .medium,
            theme: .light
        )

        #expect(reading.contains("Title"))
        #expect(reading.contains("Body text"))
        #expect(reading.contains("font-size: 18px"))
    }

    @Test func fallsBackToBody() {
        let reading = HTMLContentExtractor.readingHTML(
            from: "<html><body><p>plain body</p></body></html>",
            fontSize: .small,
            theme: .dark
        )

        #expect(reading.contains("plain body"))
        #expect(reading.contains("#1c1c1e"))
    }
}
