import Foundation

/// Wire format between the CLI and the menu bar app: one JSON object per
/// connection, newline-terminated, answered by one JSON `Response`.
struct Request: Codable {
    var cmd: String
    var args: [String] = []
    var opts: [String: String] = [:]
}

struct Response: Codable {
    var ok: Bool
    var message: String
    var status: Status?
    var tracks: [TrackInfo]?
}

struct TrackInfo: Codable {
    var index: Int
    var title: String
    var path: String
    var current: Bool
}

enum PlayState: String, Codable { case stopped, playing, paused }
enum RepeatMode: String, Codable { case off, all, one }

struct Status: Codable {
    var state: PlayState
    var index: Int?
    var count: Int
    var title: String?
    var path: String?
    var position: Double
    var duration: Double?
    var volume: Float
    var repeatMode: RepeatMode
}

/// Where the app listens. Short and space-free: unix socket paths cap at 104 bytes.
enum Paths {
    static let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".jukebox")
    static let socket = dir.appendingPathComponent("jukebox.sock").path
    static let state = dir.appendingPathComponent("state.json")
    static let log = dir.appendingPathComponent("jukebox.log")
}

/// Append a line to ~/.jukebox/jukebox.log when JUKEBOX_DEBUG is set.
func debugLog(_ line: String) {
    guard ProcessInfo.processInfo.environment["JUKEBOX_DEBUG"] != nil else { return }
    let stamp = ISO8601DateFormatter().string(from: Date())
    if let h = try? FileHandle(forWritingTo: Paths.log) {
        h.seekToEndOfFile()
        h.write(Data("\(stamp) \(line)\n".utf8))
        try? h.close()
    }
}
