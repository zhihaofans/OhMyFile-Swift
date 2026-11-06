import Foundation
import Testing
@testable import OhMyFile

struct FileCategoryTests {
    private func category(for fileName: String) -> FileCategory {
        FileCategoryResolver.category(
            for: URL(fileURLWithPath: "/tmp/ohmyfile-category/\(fileName)")
        )
    }

    @Test func images() {
        #expect(category(for: "photo.png") == .image)
        #expect(category(for: "photo.jpg") == .image)
    }

    @Test func videos() {
        #expect(category(for: "clip.mp4") == .video)
    }

    @Test func audio() {
        #expect(category(for: "song.mp3") == .audio)
    }

    @Test func pdf() {
        #expect(category(for: "doc.pdf") == .pdf)
    }

    @Test func text() {
        #expect(category(for: "note.txt") == .text)
        #expect(category(for: "readme.md") == .text)
        #expect(category(for: "data.json") == .text)
        #expect(category(for: "feed.xml") == .text)
        #expect(category(for: "table.csv") == .text)
    }

    @Test func documents() {
        #expect(category(for: "report.docx") == .document)
        #expect(category(for: "sheet.xlsx") == .document)
    }

    @Test func archives() {
        #expect(category(for: "bundle.zip") == .archive)
    }

    @Test func other() {
        #expect(category(for: "blob.bin") == .other)
    }
}
