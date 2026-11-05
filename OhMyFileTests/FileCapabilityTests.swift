import Foundation
import Testing
@testable import OhMyFile

struct FileCapabilityTests {
    private func capability(for fileName: String) -> FileCapability {
        FileCapabilityResolver.capability(
            for: URL(fileURLWithPath: "/tmp/ohmyfile-tests/\(fileName)")
        )
    }

    @Test func textIsPreviewableAndEditable() {
        let capability = capability(for: "note.txt")
        #expect(capability.canPreview)
        #expect(capability.canEdit)
        #expect(capability.canExport)
    }

    @Test func markdownIsPreviewableAndEditable() {
        let capability = capability(for: "readme.md")
        #expect(capability.canPreview)
        #expect(capability.canEdit)
    }

    @Test func jsonIsPreviewableAndEditable() {
        let capability = capability(for: "data.json")
        #expect(capability.canPreview)
        #expect(capability.canEdit)
    }

    @Test func xmlIsPreviewableAndEditable() {
        let capability = capability(for: "feed.xml")
        #expect(capability.canPreview)
        #expect(capability.canEdit)
    }

    @Test func csvIsPreviewableAndEditable() {
        let capability = capability(for: "table.csv")
        #expect(capability.canPreview)
        #expect(capability.canEdit)
    }

    @Test func pdfIsPreviewableButNotEditable() {
        let capability = capability(for: "doc.pdf")
        #expect(capability.canPreview)
        #expect(!capability.canEdit)
        #expect(capability.canExport)
    }

    @Test func pngIsPreviewableButNotEditable() {
        let capability = capability(for: "photo.png")
        #expect(capability.canPreview)
        #expect(!capability.canEdit)
    }

    @Test func unknownBinaryHasNoPreviewOrEdit() {
        let capability = capability(for: "blob.bin")
        #expect(!capability.canPreview)
        #expect(!capability.canEdit)
        #expect(capability.canExport)
    }
}
