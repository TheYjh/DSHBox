//
//  LocalHTTPServer.swift
//  重铸百科 iOS
//
//  一个只监听回环地址的极简 HTTP/1.1 静态文件服务。
//
//  为什么需要它：web.pack 里的页面靠 document.head.append(<script src=...>) 逐条按需
//  加载词条数据（app.js 里没有任何 fetch/XHR），用 file:// 打开会被同源策略挡下，
//  所以必须给 WKWebView 一个真正的 http 源。同时 http://127.0.0.1:<固定端口> 是一个
//  稳定同源，收藏用的 localStorage 才能跨次启动保留。
//

import Foundation

final class LocalHTTPServer {

    enum ServerError: LocalizedError {
        case socketUnavailable(Int32)
        case bindFailed(port: UInt16, errno: Int32)
        case listenFailed(Int32)
        case invalidRoot(String)

        var errorDescription: String? {
            switch self {
            case .socketUnavailable(let code):
                return "无法创建套接字（errno \(code)）"
            case .bindFailed(let port, let code):
                return "端口 \(port) 绑定失败（errno \(code)）"
            case .listenFailed(let code):
                return "监听失败（errno \(code)）"
            case .invalidRoot(let path):
                return "网页资源目录不可用：\(path)"
            }
        }
    }

    /// 依次尝试的端口。始终保持同一顺序，让 localStorage 的同源（含端口）在重启后不变。
    static let preferredPorts: [UInt16] = [39471, 39472, 39473, 39474, 39475, 39476]

    private let rootDirectory: URL
    private let acceptQueue = DispatchQueue(label: "com.dshbox.zhongzhuwiki.http.accept")
    private let workerQueue = DispatchQueue(label: "com.dshbox.zhongzhuwiki.http.worker",
                                           qos: .userInitiated,
                                           attributes: .concurrent)

    private var listenFD: Int32 = -1
    private var running = false
    private(set) var port: UInt16 = 0

    init(rootDirectory: URL) throws {
        let standardized = rootDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ServerError.invalidRoot(standardized.path)
        }
        self.rootDirectory = standardized
    }

    deinit {
        stop()
    }

    /// 启动服务，返回实际监听的端口。
    func start() throws -> UInt16 {
        guard !running else { return port }

        var lastError: Error?
        for candidate in LocalHTTPServer.preferredPorts {
            do {
                try bind(port: candidate)
                port = candidate
                running = true
                startAcceptLoop()
                return candidate
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError ?? ServerError.listenFailed(0)
    }

    func stop() {
        guard running else { return }
        running = false
        if listenFD >= 0 {
            Darwin.shutdown(listenFD, SHUT_RDWR)
            Darwin.close(listenFD)
            listenFD = -1
        }
    }

    // MARK: - 监听

    private func bind(port candidate: UInt16) throws {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.socketUnavailable(errno) }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = candidate.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &address) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(fd, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            let code = errno
            Darwin.close(fd)
            throw ServerError.bindFailed(port: candidate, errno: code)
        }

        guard Darwin.listen(fd, 32) == 0 else {
            let code = errno
            Darwin.close(fd)
            throw ServerError.listenFailed(code)
        }

        listenFD = fd
    }

    private func startAcceptLoop() {
        let fd = listenFD
        acceptQueue.async { [weak self] in
            guard let self = self else { return }
            while self.running {
                let client = Darwin.accept(fd, nil, nil)
                if client < 0 {
                    if errno == EINTR { continue }
                    // 监听套接字被关闭或出错，退出循环
                    break
                }
                self.workerQueue.async {
                    self.handle(client: client)
                }
            }
        }
    }

    // MARK: - 请求处理

    private func handle(client: Int32) {
        defer { Darwin.close(client) }

        var noSigPipe: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        guard let head = readRequestHead(from: client) else {
            send(status: 408, reason: "Request Timeout", contentType: "text/plain; charset=utf-8",
                 body: Data("timeout".utf8), to: client, includeBody: true)
            return
        }

        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            send(status: 400, reason: "Bad Request", contentType: "text/plain; charset=utf-8",
                 body: Data("bad request".utf8), to: client, includeBody: true)
            return
        }

        let method = String(parts[0]).uppercased()
        guard method == "GET" || method == "HEAD" else {
            send(status: 405, reason: "Method Not Allowed", contentType: "text/plain; charset=utf-8",
                 body: Data("method not allowed".utf8), to: client, includeBody: method != "HEAD")
            return
        }

        var rawPath = String(parts[1])
        if let queryStart = rawPath.firstIndex(of: "?") {
            rawPath = String(rawPath[rawPath.startIndex..<queryStart])
        }
        if let hashStart = rawPath.firstIndex(of: "#") {
            rawPath = String(rawPath[rawPath.startIndex..<hashStart])
        }
        guard let decodedPath = rawPath.removingPercentEncoding else {
            send(status: 400, reason: "Bad Request", contentType: "text/plain; charset=utf-8",
                 body: Data("bad path".utf8), to: client, includeBody: method != "HEAD")
            return
        }

        guard let fileURL = resolve(decodedPath) else {
            send(status: 404, reason: "Not Found", contentType: "text/plain; charset=utf-8",
                 body: Data("not found".utf8), to: client, includeBody: method != "HEAD")
            return
        }

        guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
            send(status: 404, reason: "Not Found", contentType: "text/plain; charset=utf-8",
                 body: Data("not found".utf8), to: client, includeBody: method != "HEAD")
            return
        }

        send(status: 200, reason: "OK", contentType: LocalHTTPServer.contentType(for: fileURL.pathExtension),
             body: data, to: client, includeBody: method != "HEAD")
    }

    /// 读取请求头（直到空行为止），最多 64 KB。
    private func readRequestHead(from client: Int32) -> String? {
        let terminator = Data("\r\n\r\n".utf8)
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 8192)

        while buffer.count < 65536 {
            let received = chunk.withUnsafeMutableBytes { raw -> Int in
                guard let base = raw.baseAddress else { return 0 }
                return Darwin.read(client, base, raw.count)
            }
            if received < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if received == 0 { break }
            buffer.append(contentsOf: chunk[0..<received])
            if let range = buffer.range(of: terminator) {
                return String(data: buffer[buffer.startIndex..<range.lowerBound], encoding: .utf8)
            }
        }
        return nil
    }

    /// 把请求路径映射到根目录内的文件；越界访问一律返回 nil。
    private func resolve(_ decodedPath: String) -> URL? {
        var relative = decodedPath.hasPrefix("/") ? String(decodedPath.dropFirst()) : decodedPath
        if relative.isEmpty { relative = "index.html" }
        guard !relative.contains("..") else { return nil }

        let url = rootDirectory.appendingPathComponent(relative).standardizedFileURL
        let rootPath = rootDirectory.path.hasSuffix("/") ? rootDirectory.path : rootDirectory.path + "/"
        guard url.path.hasPrefix(rootPath) else { return nil }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue {
            let index = url.appendingPathComponent("index.html")
            return FileManager.default.fileExists(atPath: index.path) ? index : nil
        }
        return url
    }

    // MARK: - 响应

    private func send(status: Int, reason: String, contentType: String, body: Data,
                      to client: Int32, includeBody: Bool) {
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-cache\r\n"
        head += "Accept-Ranges: none\r\n"
        head += "Connection: close\r\n\r\n"

        var payload = Data(head.utf8)
        if includeBody { payload.append(body) }
        write(payload, to: client)
    }

    private func write(_ data: Data, to client: Int32) {
        var offset = 0
        let total = data.count
        while offset < total {
            let sent = data.withUnsafeBytes { raw -> Int in
                guard let base = raw.baseAddress else { return -1 }
                return Darwin.send(client, base.advanced(by: offset), total - offset, 0)
            }
            if sent <= 0 {
                if errno == EINTR { continue }
                return
            }
            offset += sent
        }
    }

    static func contentType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js", "mjs": return "application/javascript; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "txt", "md": return "text/plain; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "wav": return "audio/wav"
        case "mp4": return "video/mp4"
        case "ics": return "text/calendar; charset=utf-8"
        default: return "application/octet-stream"
        }
    }
}
