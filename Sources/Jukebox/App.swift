import AppKit
import MediaPlayer

/// The menu bar half: owns the engine, the socket server and the media-key hookup.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let engine = Engine()
    lazy var handler = Handler(engine: engine)
    let server = SocketServer()
    var item: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        handler.quit = { DispatchQueue.main.async { NSApp.terminate(nil) } }
        do { try server.start(handler) } catch {
            fputs("jukebox: \(error.localizedDescription)\n", stderr)
            NSApp.terminate(nil)
            return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = NSMenu()
        item.menu?.delegate = self
        engine.onChange = { [weak self] in self?.refreshIcon() }
        refreshIcon()
        registerMediaKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
        server.stop()
    }

    private func refreshIcon() {
        let symbol = engine.state == .playing ? "play.circle.fill" : (engine.state == .paused ? "pause.circle" : "music.note.list")
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Jukebox")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = engine.current?.title ?? "Jukebox"
    }

    /// Hardware play/pause/next/previous keys, the touch bar and Control Center all land here.
    private func registerMediaKeys() {
        let c = MPRemoteCommandCenter.shared()
        for (name, cmd) in [("play", c.playCommand), ("pause", c.pauseCommand), ("toggle", c.togglePlayPauseCommand),
                            ("next", c.nextTrackCommand), ("prev", c.previousTrackCommand)] {
            cmd.isEnabled = true
            cmd.addTarget { _ in debugLog("remote \(name)"); return .success }
        }
        c.playCommand.addTarget { [weak self] _ in self?.engine.resume(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.engine.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.engine.toggle(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.engine.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.engine.previous(); return .success }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.engine.seek(to: e.positionTime)
            return .success
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = engine.status()
        let title = NSMenuItem(title: s.title ?? "Nothing playing", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        if s.count > 0, let i = s.index {
            let sub = NSMenuItem(title: "Track \(i + 1) of \(s.count)", action: nil, keyEquivalent: "")
            sub.isEnabled = false
            menu.addItem(sub)
        }
        menu.addItem(.separator())
        add(menu, s.state == .playing ? "Pause" : "Play", #selector(toggle))
        add(menu, "Next", #selector(next))
        add(menu, "Previous", #selector(previous))
        menu.addItem(.separator())
        let reveal = NSMenuItem(title: "Show in Finder", action: s.path == nil ? nil : #selector(revealCurrent), keyEquivalent: "")
        reveal.target = self
        menu.addItem(reveal)
        menu.addItem(.separator())

        let queue = NSMenuItem(title: "Queue (\(engine.tracks.count))", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let start = max(0, (engine.index ?? 0) - 2)
        for i in start..<min(engine.tracks.count, start + 25) {
            let row = NSMenuItem(title: engine.tracks[i].title, action: #selector(jump(_:)), keyEquivalent: "")
            row.target = self
            row.tag = i
            row.state = i == engine.index ? .on : .off
            sub.addItem(row)
        }
        if engine.tracks.isEmpty { sub.addItem(NSMenuItem(title: "Empty. Run: jukebox cue <folder>", action: nil, keyEquivalent: "")) }
        queue.submenu = sub
        menu.addItem(queue)
        add(menu, "Shuffle upcoming", #selector(shuffle))
        let rep = NSMenuItem(title: "Repeat: \(engine.repeatMode.rawValue)", action: #selector(cycleRepeat), keyEquivalent: "")
        rep.target = self
        menu.addItem(rep)
        add(menu, "Clear queue", #selector(clear))
        menu.addItem(.separator())
        add(menu, "Quit Jukebox", #selector(quit), key: "q")
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        menu.addItem(i)
    }

    @objc func revealCurrent() { _ = engine.revealCurrent() }
    @objc func toggle() { engine.toggle() }
    @objc func next() { engine.next() }
    @objc func previous() { engine.previous() }
    @objc func shuffle() { engine.shuffleUpcoming() }
    @objc func clear() { engine.clear() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func jump(_ sender: NSMenuItem) { engine.jump(to: sender.tag) }
    @objc func cycleRepeat() {
        engine.setRepeat([.off: .all, .all: .one, .one: .off][engine.repeatMode] ?? .off)
    }
}

func runApp() -> Never {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
    exit(0)
}
