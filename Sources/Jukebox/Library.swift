import Foundation

struct Track: Codable, Equatable {
    var path: String
    var title: String

    init(path: String) {
        self.path = path
        self.title = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}

/// Turns files, folders and .m3u playlists into an ordered list of playable paths.
enum Library {
    static let audioExtensions: Set<String> = ["wav", "mp3", "m4a", "aif", "aiff", "flac", "aac", "caf", "alac", "mp4"]

    static func isAudio(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return audioExtensions.contains(url.pathExtension.lowercased()) && !name.hasPrefix("._")
    }

    /// `dedupe` drops later copies with the same file name and size, which is how a
    /// mixdown folder ends up holding the same bounce twice.
    static func collect(_ inputs: [String], dedupe: Bool = true) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        let fm = FileManager.default

        func add(_ url: URL) {
            guard isAudio(url), fm.fileExists(atPath: url.path) else { return }
            if dedupe {
                let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                let key = "\(url.lastPathComponent.lowercased())|\(size)"
                guard seen.insert(key).inserted else { return }
            }
            out.append(url.path)
        }

        for input in inputs {
            let url = URL(fileURLWithPath: (input as NSString).expandingTildeInPath).standardizedFileURL
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let walker = fm.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                let files = (walker?.allObjects as? [URL] ?? [])
                    .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                files.forEach(add)
            } else if ["m3u", "m3u8"].contains(url.pathExtension.lowercased()) {
                parseM3U(url).forEach(add)
            } else {
                add(url)
            }
        }
        return out
    }

    static func parseM3U(_ url: URL) -> [URL] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let base = url.deletingLastPathComponent()
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : base.appendingPathComponent($0).standardizedFileURL }
    }
}
