//
//  HTMLContentExtractor.swift
//  OhMyFile
//
//  HTML 清洗与阅读模式正文提取：移除脚本、远程资源与事件属性。
//  纯内核代码，不依赖 WebKit。
//

import Foundation

enum HTMLReadingTheme: String, CaseIterable {
    case system
    case light
    case dark
}

enum HTMLFontSize: String, CaseIterable {
    case small
    case medium
    case large

    var points: CGFloat {
        switch self {
        case .small:
            return 15
        case .medium:
            return 18
        case .large:
            return 22
        }
    }
}

enum HTMLContentExtractor {
    nonisolated static func sanitize(_ html: String) -> String {
        var result = html

        result = replacingMatches(
            #"<script\b[^>]*>.*?</script>"#,
            in: result
        )
        result = replacingMatches(
            #"<iframe\b[^>]*>.*?</iframe>"#,
            in: result
        )
        result = replacingMatches(
            #"<(object|embed|noscript)\b[^>]*>.*?</\1>"#,
            in: result
        )
        result = replacingMatches(
            #"\son[a-z]+\s*=\s*"[^"]*""#,
            in: result
        )
        result = replacingMatches(
            #"\son[a-z]+\s*=\s*'[^']*'"#,
            in: result
        )
        result = replacingMatches(
            #"href\s*=\s*["']javascript:[^"']*["']"#,
            in: result
        )
        result = replacingMatches(
            #"<img\b[^>]*src\s*=\s*["']https?://[^"']*["'][^>]*>"#,
            in: result
        )
        result = replacingMatches(
            #"<link\b[^>]*href\s*=\s*["']https?://[^"']*["'][^>]*>"#,
            in: result
        )
        result = replacingMatches(
            #"@import\s+url\([^)]*\)\s*;"#,
            in: result
        )

        return result
    }

    nonisolated static func readingHTML(
        from sanitizedHTML: String,
        fontSize: HTMLFontSize,
        theme: HTMLReadingTheme
    ) -> String {
        let body = extractBody(from: sanitizedHTML)
        let css = readingCSS(fontSize: fontSize, theme: theme)

        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    private nonisolated static func extractBody(from html: String) -> String {
        for tag in ["article", "main"] {
            if let content = firstGroup(
                #"<\#(tag)\b[^>]*>(.*?)</\#(tag)>"#,
                in: html
            ) {
                return content
            }
        }

        if let content = firstGroup(#"<body\b[^>]*>(.*?)</body>"#, in: html) {
            return content
        }

        return html
    }

    private nonisolated static func readingCSS(
        fontSize: HTMLFontSize,
        theme: HTMLReadingTheme
    ) -> String {
        let size = fontSize.points
        let base = """
        body {
            font-family: -apple-system, sans-serif;
            font-size: \(Int(size))px;
            line-height: 1.75;
            margin: 20px;
            padding-bottom: 40px;
            word-wrap: break-word;
        }
        img, video { max-width: 100%; height: auto; }
        pre { overflow-x: auto; }
        a { text-decoration: none; }
        """

        switch theme {
        case .system:
            return base + """
            :root { color-scheme: light dark; }
            body { background: #ffffff; color: #1c1c1e; }
            a { color: #0a84ff; }
            @media (prefers-color-scheme: dark) {
                body { background: #1c1c1e; color: #eaf3ff; }
                a { color: #64b5ff; }
            }
            """

        case .light:
            return base + """
            body { background: #ffffff; color: #1c1c1e; }
            a { color: #0a84ff; }
            """

        case .dark:
            return base + """
            body { background: #1c1c1e; color: #eaf3ff; }
            a { color: #64b5ff; }
            """
        }
    }

    private nonisolated static func firstGroup(_ pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let fullRange = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: fullRange),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }

        return String(string[range])
    }

    private nonisolated static func replacingMatches(_ pattern: String, in string: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return string
        }

        return regex.stringByReplacingMatches(
            in: string,
            range: NSRange(string.startIndex..., in: string),
            withTemplate: ""
        )
    }
}
