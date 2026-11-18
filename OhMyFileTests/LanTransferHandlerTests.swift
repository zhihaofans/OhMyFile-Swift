import Foundation
import FlyingFox
import Testing
@testable import OhMyFile

struct LanTransferHandlerTests {
    @Test func uploadsAndDownloadsFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let library = FileLibrary(rootURL: root)
        let handler = LanTransferHandler(library: library)

        let upload = HTTPRequest(
            method: .POST,
            version: .http11,
            path: "/upload",
            query: [HTTPRequest.QueryItem(name: "name", value: "hello.txt")],
            headers: [:],
            body: Data("hello".utf8)
        )
        let uploadResponse = try await handler.handleRequest(upload)
        #expect(uploadResponse.statusCode == .ok)

        let download = HTTPRequest(
            method: .GET,
            version: .http11,
            path: "/download",
            query: [HTTPRequest.QueryItem(name: "path", value: "hello.txt")],
            headers: [:],
            body: Data()
        )
        let downloadResponse = try await handler.handleRequest(download)
        #expect(downloadResponse.statusCode == .ok)
        let body = try await downloadResponse.bodyData
        #expect(body == Data("hello".utf8))
    }

    @Test func rejectsPathTraversal() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let handler = LanTransferHandler(library: FileLibrary(rootURL: root))

        let download = HTTPRequest(
            method: .GET,
            version: .http11,
            path: "/download",
            query: [HTTPRequest.QueryItem(name: "path", value: "../secret.txt")],
            headers: [:],
            body: Data()
        )
        let downloadResponse = try await handler.handleRequest(download)
        #expect(downloadResponse.statusCode == .badRequest)

        let upload = HTTPRequest(
            method: .POST,
            version: .http11,
            path: "/upload",
            query: [HTTPRequest.QueryItem(name: "name", value: "../evil.txt")],
            headers: [:],
            body: Data("x".utf8)
        )
        let uploadResponse = try await handler.handleRequest(upload)
        #expect(uploadResponse.statusCode == .badRequest)
    }
}
