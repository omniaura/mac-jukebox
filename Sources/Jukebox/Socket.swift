import Foundation

private func makeAddr(_ path: String) -> sockaddr_un {
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutablePointer(to: &addr.sun_path) {
        $0.withMemoryRebound(to: CChar.self, capacity: 104) { dst in
            _ = path.withCString { strncpy(dst, $0, 103) }
        }
    }
    return addr
}

private func withSockaddr<T>(_ addr: inout sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
    withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
}

private func readAll(_ fd: Int32, untilNewline: Bool) -> Data {
    var data = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while data.count < 4_000_000 {
        let n = read(fd, &buf, buf.count)
        if n <= 0 { break }
        data.append(contentsOf: buf[0..<n])
        if untilNewline, buf[0..<n].contains(10) { break }
    }
    return data
}

private func writeAll(_ fd: Int32, _ data: Data) {
    data.withUnsafeBytes { raw in
        var off = 0
        while off < raw.count {
            let n = write(fd, raw.baseAddress! + off, raw.count - off)
            if n <= 0 { break }
            off += n
        }
    }
}

/// Unix-socket server inside the menu bar app. Requests hop to the main queue
/// so the engine stays single-threaded.
final class SocketServer {
    private var source: DispatchSourceRead?
    private var fd: Int32 = -1

    func start(_ handler: Handler) throws {
        try FileManager.default.createDirectory(at: Paths.dir, withIntermediateDirectories: true)
        unlink(Paths.socket)
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        var addr = makeAddr(Paths.socket)
        guard withSockaddr(&addr, { bind(fd, $0, $1) }) == 0, listen(fd, 16) == 0 else {
            throw NSError(domain: "jukebox", code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "cannot listen on \(Paths.socket): \(String(cString: strerror(errno)))"])
        }
        chmod(Paths.socket, 0o600)
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        src.setEventHandler { [fd] in
            let client = accept(fd, nil, nil)
            guard client >= 0 else { return }
            var one: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
            DispatchQueue.global().async {
                defer { close(client) }
                let reply: Response
                if let req = try? JSONDecoder().decode(Request.self, from: readAll(client, untilNewline: true)) {
                    reply = DispatchQueue.main.sync { handler.handle(req) }
                } else {
                    reply = Response(ok: false, message: "malformed request", status: nil)
                }
                writeAll(client, (try? JSONEncoder().encode(reply)) ?? Data())
            }
        }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        if fd >= 0 { close(fd) }
        unlink(Paths.socket)
    }
}

enum Client {
    /// Returns nil when nothing is listening.
    static func send(_ req: Request) -> Response? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var addr = makeAddr(Paths.socket)
        guard withSockaddr(&addr, { connect(fd, $0, $1) }) == 0 else { return nil }
        guard var line = try? JSONEncoder().encode(req) else { return nil }
        line.append(10)
        writeAll(fd, line)
        return try? JSONDecoder().decode(Response.self, from: readAll(fd, untilNewline: false))
    }
}
