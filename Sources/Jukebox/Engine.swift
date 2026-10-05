import AppKit
import AVFoundation
import Foundation
import MediaPlayer

/// Owns the queue and the player. Everything here runs on the main thread.
final class Engine {
    private(set) var tracks: [Track] = []
    private(set) var index: Int?
    private(set) var state: PlayState = .stopped
    private(set) var repeatMode: RepeatMode = .off
    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?
    /// Where `play` resumes after the queue ran out; lets "cue more, then play" start on the new tracks.
    private var resumeFrom = 0
    var onChange: (() -> Void)?

    var volume: Float {
        get { player.volume }
        set { player.volume = max(0, min(1, newValue)); save() }
    }

    init() {
        restore()
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }

    // MARK: Queue

    @discardableResult
    func cue(_ paths: [String], next: Bool = false, shuffle: Bool = false) -> Int {
        var added = paths.map { Track(path: $0) }
        if shuffle { added.shuffle() }
        let at = next ? (index.map { $0 + 1 } ?? tracks.count) : tracks.count
        tracks.insert(contentsOf: added, at: min(at, tracks.count))
        if index == nil, resumeFrom > tracks.count - added.count { resumeFrom = tracks.count - added.count }
        changed()
        return added.count
    }

    /// Paths that are queued but have not played yet; `cue` skips these so agents can re-run it safely.
    var upcomingPaths: Set<String> {
        let from = index.map { $0 + 1 } ?? min(resumeFrom, tracks.count)
        return Set(tracks[from...].map(\.path))
    }

    func clear() {
        stop()
        tracks = []
        index = nil
        resumeFrom = 0
        changed()
    }

    func remove(_ position: Int) -> Bool {
        guard tracks.indices.contains(position) else { return false }
        if position == index {
            tracks.remove(at: position)
            if tracks.indices.contains(position) { load(position, autoplay: state == .playing) } else { finishQueue() }
        } else {
            tracks.remove(at: position)
            if let i = index, position < i { index = i - 1 }
        }
        changed()
        return true
    }

    /// Reorders the tracks that have not played yet.
    func shuffleUpcoming() {
        let start = (index ?? resumeFrom) + (index == nil ? 0 : 1)
        guard start < tracks.count else { return }
        tracks.replaceSubrange(start..., with: tracks[start...].shuffled())
        changed()
    }

    func setRepeat(_ mode: RepeatMode) { repeatMode = mode; changed() }

    // MARK: Transport

    @discardableResult
    func play() -> Bool {
        guard !tracks.isEmpty else { return false }
        if state == .paused { resume(); return true }
        if state == .playing { return true }
        let start = index ?? (resumeFrom < tracks.count ? resumeFrom : 0)
        return load(start, autoplay: true)
    }

    func pause() {
        guard state == .playing else { return }
        player.pause()
        state = .paused
        changed()
    }

    func resume() {
        if state == .paused { player.play(); state = .playing; changed() } else { play() }
    }

    func toggle() { state == .playing ? pause() : resume() }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        state = .stopped
        changed()
    }

    @discardableResult
    func next() -> Bool {
        guard let i = index else { return play() }
        if i + 1 < tracks.count { return load(i + 1, autoplay: true) }
        if repeatMode == .all { return load(0, autoplay: true) }
        finishQueue()
        return false
    }

    /// Past the first three seconds, "previous" restarts the track like every other player.
    @discardableResult
    func previous() -> Bool {
        guard let i = index else { return false }
        if player.currentTime().seconds > 3 || i == 0 { seek(to: 0); return true }
        return load(i - 1, autoplay: true)
    }

    @discardableResult
    func jump(to position: Int) -> Bool {
        guard tracks.indices.contains(position) else { return false }
        return load(position, autoplay: true)
    }

    func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: max(0, seconds), preferredTimescale: 600))
        updateNowPlaying()
    }

    // MARK: Internals

    @discardableResult
    private func load(_ position: Int, autoplay: Bool) -> Bool {
        var position = position
        var skipped = 0
        // Skip files that vanished (an unmounted drive) instead of stalling the queue.
        while tracks.indices.contains(position), !FileManager.default.isReadableFile(atPath: tracks[position].path) {
            position += 1
            skipped += 1
        }
        guard tracks.indices.contains(position) else {
            finishQueue()
            return false
        }
        let item = AVPlayerItem(url: URL(fileURLWithPath: tracks[position].path))
        if let old = endObserver { NotificationCenter.default.removeObserver(old) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.trackEnded()
        }
        player.replaceCurrentItem(with: item)
        index = position
        if autoplay { player.play(); state = .playing } else { state = .paused }
        changed()
        return true
    }

    private func trackEnded() {
        if repeatMode == .one, let i = index { load(i, autoplay: true); return }
        next()
    }

    private func finishQueue() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        resumeFrom = tracks.count
        index = nil
        state = .stopped
        changed()
    }

    private func changed() {
        save()
        updateNowPlaying()
        onChange?()
    }

    /// Selects the playing file in a Finder window (the containing folder opens with it highlighted).
    @discardableResult
    func revealCurrent() -> Bool {
        guard let track = current else { return false }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: track.path)])
        return true
    }

    var current: Track? { index.flatMap { tracks.indices.contains($0) ? tracks[$0] : nil } }

    var duration: Double? {
        let d = player.currentItem?.duration.seconds
        return (d?.isFinite ?? false) ? d : nil
    }

    func status() -> Status {
        Status(
            state: state, index: index, count: tracks.count, title: current?.title, path: current?.path,
            position: max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0),
            duration: duration, volume: player.volume, repeatMode: repeatMode)
    }

    private func updateNowPlaying() {
        let center = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            center.nowPlayingInfo = nil
            center.playbackState = .stopped
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0),
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if let d = duration { info[MPMediaItemPropertyPlaybackDuration] = d }
        center.nowPlayingInfo = info
        center.playbackState = state == .playing ? .playing : (state == .paused ? .paused : .stopped)
    }

    // MARK: Persistence

    private struct Saved: Codable {
        var tracks: [Track]
        var index: Int?
        var resumeFrom: Int
        var repeatMode: RepeatMode
        var volume: Float
    }

    private func save() {
        let saved = Saved(tracks: tracks, index: index, resumeFrom: resumeFrom, repeatMode: repeatMode, volume: player.volume)
        try? FileManager.default.createDirectory(at: Paths.dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(saved).write(to: Paths.state, options: .atomic)
    }

    /// Restores the queue but never auto-plays: relaunching must not blast music.
    private func restore() {
        guard let data = try? Data(contentsOf: Paths.state), let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        tracks = saved.tracks
        repeatMode = saved.repeatMode
        player.volume = saved.volume
        resumeFrom = saved.index ?? saved.resumeFrom
    }
}
