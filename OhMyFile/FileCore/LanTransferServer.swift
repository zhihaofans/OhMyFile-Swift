//
//  LanTransferServer.swift
//  OhMyFile
//
//  局域网 / 热点文件传输：内置 HTTP 服务，电脑浏览器可浏览、上传、下载收件箱文件。
//  仅在用户显式开启时监听，页面关闭或 App 退到后台即停止。
//

import Darwin
import Foundation
import FlyingFox
import OSLog
import UniformTypeIdentifiers

struct LanTransferSession: Sendable {
    let address: String
    let port: UInt16
}

enum LanTransferError: Error, Equatable {
    case noLocalAddress
    case startFailed
    case portUnavailable
}

enum LanPortChecker {
    nonisolated static func isAvailable(_ port: UInt16) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = INADDR_ANY

        let result = withUnsafePointer(to: &address) {
            bind(fd, UnsafePointer<sockaddr>(OpaquePointer($0)), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        return result == 0
    }
}

final class LanTransferServer {
    private let library: FileLibrary
    private var server: HTTPServer?
    private var runTask: Task<Void, Never>?

    nonisolated init(library: FileLibrary = FileLibrary()) {
        self.library = library
    }

    func start(port: UInt16) async throws -> LanTransferSession {
        stop()

        guard LanPortChecker.isAvailable(port) else {
            AppLog.lan.error("server start failed: port \(port, privacy: .public) unavailable")
            throw LanTransferError.portUnavailable
        }

        AppLog.lan.info("server starting port=\(port, privacy: .public)")

        let server = HTTPServer(port: port, handler: LanTransferHandler(library: library))
        self.server = server

        runTask = Task {
            try? await server.run()
        }

        try? await Task.sleep(nanoseconds: 150_000_000)

        guard let host = LanAddress.currentLANAddress() else {
            AppLog.lan.error("server start failed: no local address")
            stop()
            throw LanTransferError.noLocalAddress
        }

        let session = LanTransferSession(address: "http://\(host):\(port)/", port: port)
        AppLog.lan.info("server started address=\(session.address, privacy: .public)")
        return session
    }

    func stop() {
        guard runTask != nil || server != nil else { return }

        runTask?.cancel()
        runTask = nil
        server = nil
        AppLog.lan.info("server stopped")
    }
}

enum LanAddress {
    nonisolated static func currentLANAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var candidates: [(name: String, ip: String)] = []

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                address,
                socklen_t(address.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }

            let ip = String(cString: hostname)
            guard !ip.isEmpty, ip != "127.0.0.1" else { continue }
            candidates.append((name, ip))
        }

        return candidates.first(where: { $0.name == "en0" })?.ip ?? candidates.first?.ip
    }
}

struct LanTransferHandler: HTTPHandler {
    let library: FileLibrary

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        AppLog.lan.info(
            "request \(request.method.rawValue, privacy: .public) \(request.path, privacy: .public)"
        )

        switch (request.method, request.path) {
        case (.GET, "/"):
            return htmlResponse()
        case (.POST, "/upload"):
            return await uploadResponse(request)
        case (.GET, "/download"):
            return downloadResponse(request)
        default:
            return HTTPResponse(statusCode: .notFound)
        }
    }

    private func htmlResponse() -> HTTPResponse {
        let inboxURL = library.directoryURL(for: .inbox)
        let files = inboxURL.map { library.contents(at: $0).filter { !$0.isDirectory } } ?? []
        AppLog.lan.info("served file list: \(files.count, privacy: .public) files")

        var rows = ""
        for file in files {
            let encodedPath = file.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? file.name
            rows += """
            <li><a href="/download?path=\(encodedPath)">\(htmlEscape(file.name))</a><span>\(formatBytes(file.size ?? 0))</span></li>
            """
        }

        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>OhMyFile</title>
        <style>
        body { font-family: -apple-system, sans-serif; margin: 0; padding: 24px; background: #f2f2f7; color: #1c1c1e; }
        h1 { font-size: 24px; margin: 0 0 4px; }
        h2 { font-size: 16px; margin: 24px 0 8px; color: #636366; }
        p { color: #636366; margin: 4px 0 16px; }
        ul { list-style: none; padding: 0; margin: 0; background: #fff; border-radius: 12px; overflow: hidden; }
        li { display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e5ea; }
        li:last-child { border-bottom: none; }
        a { color: #007aff; text-decoration: none; word-break: break-all; }
        span { color: #8e8e93; font-size: 13px; margin-left: 16px; white-space: nowrap; }
        button { background: #007aff; color: #fff; border: 0; border-radius: 10px; padding: 10px 18px; font-size: 15px; }
        input[type=file] { display: block; margin-bottom: 12px; }
        </style>
        </head>
        <body>
        <h1>OhMyFile</h1>
        <p>同一 Wi-Fi / 热点下的文件传输</p>
        <h2>收件箱</h2>
        <ul>\(rows.isEmpty ? "<li>暂无文件</li>" : rows)</ul>
        <h2>上传到收件箱</h2>
        <input type="file" id="file" multiple>
        <button onclick="upload()">上传</button>
        <p id="status"></p>
        <script>
        async function upload() {
          const files = document.getElementById('file').files;
          const status = document.getElementById('status');
          for (const file of files) {
            status.textContent = '上传中: ' + file.name;
            try {
              const response = await fetch('/upload?name=' + encodeURIComponent(file.name), { method: 'POST', body: file });
              status.textContent = response.ok ? '上传成功: ' + file.name : '上传失败: ' + file.name;
              if (response.ok) location.reload();
            } catch (error) {
              status.textContent = '上传失败: ' + file.name;
            }
          }
        }
        </script>
        </body>
        </html>
        """

        return HTTPResponse(
            statusCode: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: Data(html.utf8)
        )
    }

    private func downloadResponse(_ request: HTTPRequest) -> HTTPResponse {
        guard let path = request.query["path"],
              !path.isEmpty,
              !path.contains("/"),
              !path.contains(".."),
              let inboxURL = library.directoryURL(for: .inbox) else {
            AppLog.lan.error("download rejected: invalid path")
            return HTTPResponse(statusCode: .badRequest)
        }

        try? FileManager.default.createDirectory(
            at: inboxURL,
            withIntermediateDirectories: true
        )

        let fileURL = inboxURL.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fileURL) else {
            AppLog.lan.error("download failed: \(path, privacy: .public) not found")
            return HTTPResponse(statusCode: .notFound)
        }

        AppLog.lan.info("downloaded file: \(path, privacy: .public) size=\(data.count, privacy: .public)")

        let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return HTTPResponse(
            statusCode: .ok,
            headers: [
                .contentType: mime,
                HTTPHeader("Content-Disposition"): "attachment; filename=\"\(fileURL.lastPathComponent)\""
            ],
            body: data
        )
    }

    private func uploadResponse(_ request: HTTPRequest) async -> HTTPResponse {
        guard let name = request.query["name"],
              !name.isEmpty,
              !name.contains("/"),
              !name.contains(".."),
              let inboxURL = library.directoryURL(for: .inbox) else {
            AppLog.lan.error("upload rejected: invalid name")
            return HTTPResponse(statusCode: .badRequest)
        }

        do {
            let data = try await request.bodyData
            guard data.count <= 100 * 1024 * 1024 else {
                AppLog.lan.error("upload rejected: \(name, privacy: .public) too large=\(data.count, privacy: .public)")
                return HTTPResponse(statusCode: .payloadTooLarge)
            }

            try FileManager.default.createDirectory(
                at: inboxURL,
                withIntermediateDirectories: true
            )

            let destination = library.uniqueURL(in: inboxURL, fileName: name)
            try data.write(to: destination)
            FileTimestamps.setImported(at: Date(), for: destination)
            AppLog.lan.info("uploaded file: \(destination.lastPathComponent, privacy: .public) size=\(data.count, privacy: .public)")
            return HTTPResponse(statusCode: .ok, body: Data("OK".utf8))
        } catch {
            AppLog.lan.error("upload failed: \(name, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return HTTPResponse(statusCode: .internalServerError)
        }
    }

    private func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var index = 0

        while value >= 1000, index < units.count - 1 {
            value /= 1000
            index += 1
        }

        if index == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[index])
    }
}
