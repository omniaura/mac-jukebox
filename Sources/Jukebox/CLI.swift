import Foundation

let usage = """
jukebox: a menu bar music queue that agents and humans share

Queue
  jukebox cue <file|folder|.m3u>...   add to the end (folders recurse, duplicates dropped)
      --next        insert after the current track
      --shuffle     shuffle the tracks being added
      --play        start playing if idle
      --keep-dupes  do not drop same-name, same-size files
  jukebox list                        show the queue (▶ marks the current track)
  jukebox remove <n>                  drop track n (1-based)
  jukebox clear                       empty the queue and stop
  jukebox shuffle                     reshuffle the tracks that have not played yet
  jukebox repeat off|all|one

Transport
  jukebox play [n]    start, or jump to track n      jukebox pause | resume | toggle
  jukebox next | prev                                jukebox stop
  jukebox seek <secs|m:ss>                           jukebox volume [0-100]
  jukebox status                                     jukebox quit
  jukebox reveal                                     show the playing file in Finder

Add --json to any command for machine-readable output. Exit code is 0 on success.
The app launches itself on first use; the keyboard media keys control it too.
"""

func runCLI(_ argv: [String]) -> Never {
    let json = argv.contains("--json")
    var args = argv.filter { $0 != "--json" }
    guard let cmd = args.first else {
        print(usage)
        exit(0)
    }
    if ["-h", "--help", "help"].contains(cmd) { print(usage); exit(0) }
    if cmd == "--version" || cmd == "version" { print(version); exit(0) }
    if cmd == "daemon" || cmd == "app" { runApp() }

    var opts: [String: String] = [:]
    var positional: [String] = []
    for a in args.dropFirst() {
        switch a {
        case "--next": opts["next"] = "1"
        case "--shuffle": opts["shuffle"] = "1"
        case "--play": opts["play"] = "1"
        case "--keep-dupes": opts["dedupe"] = "0"
        default:
            // Resolve relative paths here: the app's working directory is not the caller's.
            let isPathCmd = cmd == "cue"
            positional.append(isPathCmd ? URL(fileURLWithPath: (a as NSString).expandingTildeInPath).standardizedFileURL.path : a)
        }
    }
    let req = Request(cmd: cmd, args: positional, opts: opts)

    var response = Client.send(req)
    if response == nil {
        if cmd == "quit" { print("not running"); exit(0) }
        launchApp()
        for _ in 0..<50 where response == nil {
            usleep(100_000)
            response = Client.send(req)
        }
    }
    guard let r = response else {
        fputs("jukebox: could not reach the app. See \(Paths.log.path)\n", stderr)
        exit(2)
    }

    if json {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: (try? enc.encode(r)) ?? Data(), encoding: .utf8) ?? "{}")
    } else {
        render(r, cmd: cmd)
    }
    exit(r.ok ? 0 : 1)
}

private func render(_ r: Response, cmd: String) {
    if cmd == "list", let tracks = r.tracks {
        if tracks.isEmpty { print("queue is empty") }
        for t in tracks { print("\(t.current ? "▶" : " ") \(String(format: "%3d", t.index)). \(t.title)") }
        return
    }
    if cmd == "status", let s = r.status {
        let icon = ["playing": "▶", "paused": "⏸", "stopped": "■"][s.state.rawValue] ?? "?"
        var line = "\(icon) \(s.title ?? "nothing playing")"
        if let d = s.duration, s.title != nil { line += "  \(clock(s.position))/\(clock(d))" }
        print(line)
        print("track \(s.index.map { String($0 + 1) } ?? "-") of \(s.count), volume \(Int(s.volume * 100)), repeat \(s.repeatMode.rawValue)")
        return
    }
    if r.ok { print(r.message) } else { fputs("jukebox: \(r.message)\n", stderr) }
}

private func clock(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }

/// Starts the menu bar app detached. Inside an .app bundle that means `open`;
/// from a bare build (swift run, tests) it re-executes itself as a daemon.
private func launchApp() {
    let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    let bundle = exe.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let p = Process()
    if bundle.pathExtension == "app" {
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-g", bundle.path]
    } else {
        p.executableURL = exe
        p.arguments = ["daemon"]
        try? FileManager.default.createDirectory(at: Paths.dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: Paths.log.path, contents: nil)
        if let log = try? FileHandle(forWritingTo: Paths.log) {
            p.standardOutput = log
            p.standardError = log
        }
        p.standardInput = FileHandle.nullDevice
    }
    try? p.run()
}
