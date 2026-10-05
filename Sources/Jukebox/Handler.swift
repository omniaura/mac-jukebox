import Foundation

/// Maps a CLI request onto the engine. Runs on the main thread.
final class Handler {
    let engine: Engine
    var quit: () -> Void = {}

    init(engine: Engine) { self.engine = engine }

    func handle(_ r: Request) -> Response {
        func ok(_ message: String) -> Response { Response(ok: true, message: message, status: engine.status()) }
        func fail(_ message: String) -> Response { Response(ok: false, message: message, status: engine.status()) }

        switch r.cmd {
        case "cue":
            let dedupe = r.opts["dedupe"] != "0"
            var paths = Library.collect(r.args, dedupe: dedupe)
            guard !paths.isEmpty else { return fail(noAudioMessage(r.args)) }
            if dedupe {
                let queued = engine.upcomingPaths
                paths.removeAll { queued.contains($0) }
                if paths.isEmpty {
                    if r.opts["play"] == "1" { engine.play() }
                    return ok("already queued; nothing new to add")
                }
            }
            let n = engine.cue(paths, next: r.opts["next"] == "1", shuffle: r.opts["shuffle"] == "1")
            if r.opts["play"] == "1" { engine.play() }
            return ok("cued \(n) track\(n == 1 ? "" : "s") (\(engine.tracks.count) in queue)")
        case "play":
            if let arg = r.args.first, let n = Int(arg) {
                return engine.jump(to: n - 1) ? ok("playing \(engine.current?.title ?? "")") : fail("no track \(n)")
            }
            return engine.play() ? ok("playing \(engine.current?.title ?? "")") : fail("queue is empty; cue something first")
        case "pause": engine.pause(); return ok("paused")
        case "resume": engine.resume(); return ok("playing")
        case "toggle": engine.toggle(); return ok(engine.state.rawValue)
        case "stop": engine.stop(); return ok("stopped")
        case "next": return engine.next() ? ok("playing \(engine.current?.title ?? "")") : ok("end of queue")
        case "prev", "previous": engine.previous(); return ok("playing \(engine.current?.title ?? "")")
        case "reveal": return engine.revealCurrent() ? ok("revealed \(engine.current?.title ?? "")") : fail("nothing playing")
        case "clear": engine.clear(); return ok("queue cleared")
        case "shuffle": engine.shuffleUpcoming(); return ok("shuffled upcoming tracks")
        case "remove":
            guard let n = r.args.first.flatMap(Int.init), engine.remove(n - 1) else { return fail("usage: jukebox remove <position>") }
            return ok("removed track \(n)")
        case "seek":
            guard let s = r.args.first.flatMap(parseTime) else { return fail("usage: jukebox seek <seconds|m:ss>") }
            engine.seek(to: s)
            return ok("seeked to \(Int(s))s")
        case "volume":
            guard let v = r.args.first.flatMap(Float.init), (0...100).contains(v) else {
                return ok("volume \(Int(engine.volume * 100))")
            }
            engine.volume = v / 100
            return ok("volume \(Int(v))")
        case "repeat":
            guard let mode = r.args.first.flatMap(RepeatMode.init(rawValue:)) else { return fail("usage: jukebox repeat off|all|one") }
            engine.setRepeat(mode)
            return ok("repeat \(mode.rawValue)")
        case "list":
            let infos = engine.tracks.enumerated().map {
                TrackInfo(index: $0.offset + 1, title: $0.element.title, path: $0.element.path, current: $0.offset == engine.index)
            }
            return Response(ok: true, message: "\(infos.count) in queue", status: engine.status(), tracks: infos)
        case "status", "ping": return ok(engine.state.rawValue)
        case "quit": quit(); return ok("bye")
        default: return fail("unknown command '\(r.cmd)'")
        }
    }

    /// Distinguishes "nothing there" from "macOS will not let this app look", which happens
    /// on external drives until the Removable Volumes permission is granted.
    func noAudioMessage(_ inputs: [String]) -> String {
        for input in inputs {
            do { _ = try FileManager.default.contentsOfDirectory(atPath: input) } catch let error as NSError {
                let denied = error.code == NSFileReadNoPermissionError || (error.userInfo[NSUnderlyingErrorKey] as? NSError)?.code == Int(EPERM)
                if denied {
                    return "Jukebox is not allowed to read \(input). Allow it in System Settings > Privacy & Security > Files and Folders (Removable Volumes), then retry."
                }
            }
        }
        return "no playable audio found in: \(inputs.joined(separator: ", "))"
    }

    func parseTime(_ s: String) -> Double? {
        let parts = s.split(separator: ":").map { Double($0) }
        guard !parts.isEmpty, !parts.contains(where: { $0 == nil }) else { return nil }
        return parts.compactMap { $0 }.reduce(0) { $0 * 60 + $1 }
    }
}
