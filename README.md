# mac-jukebox

A tiny macOS menu bar music queue that **agents and humans share**. An agent
can `cue` a folder and press play; you can pause, skip or reveal the file from
the menu bar, the keyboard media keys or the same CLI.

```bash
brew tap omniaura/tap
brew install --cask mac-jukebox

jukebox cue --shuffle --play ~/Music/Mixdowns
jukebox status
jukebox pause
```

The first command launches the menu bar app by itself. Playback lives in that
app (AVFoundation, a few MB of RAM, ~0% CPU), so it keeps going after the
terminal or agent session that started it is gone.

## CLI

| Command | What it does |
|---|---|
| `jukebox cue <file\|folder\|.m3u>...` | Append to the queue. Folders recurse; same-name, same-size copies are dropped; tracks already queued are skipped, so it is safe to re-run. |
| `--next` / `--shuffle` / `--play` / `--keep-dupes` | Insert after current / shuffle what is being added / start if idle / keep duplicate copies. |
| `jukebox list` | Show the queue (`▶` marks the current track). |
| `jukebox play [n]`, `pause`, `resume`, `toggle`, `stop` | Transport. `play n` jumps to track n. |
| `jukebox next`, `prev` | `prev` restarts the track after 3 seconds, like every player. |
| `jukebox seek <secs\|m:ss>`, `volume [0-100]` | |
| `jukebox shuffle`, `repeat off\|all\|one`, `remove <n>`, `clear` | Queue control. |
| `jukebox reveal` | Show the playing file in Finder. |
| `jukebox status` | Current track, position, queue size. |
| `jukebox quit` | Quit the app. |

Add `--json` to any command for machine-readable output. Exit code is `0` on
success, `1` when the command was refused (empty queue, bad index), `2` when the
app could not be reached. See [AGENTS.md](AGENTS.md) for agent usage notes.

## Menu bar

Now playing, Play/Pause, Next, Previous, **Show in Finder**, the queue (click a
row to jump), Shuffle upcoming, Repeat and Clear. The queue persists across
relaunches; relaunching never auto-plays.

## Media keys

The app registers with macOS's Now Playing system (`MPRemoteCommandCenter`), so
the keyboard's play/pause/next/previous keys, Control Center and AirPods
controls can drive it. macOS sends a media key to one app at a time. If Music,
Spotify or a browser tab has been playing, it may keep the keys until Jukebox
starts playing. Next/previous were confirmed through the system key path;
play/pause delivery was inconsistent on a machine with several other players
running. See the open issue if you hit this.

## Install from source

```bash
make install        # builds a universal app, copies it to /Applications, links `jukebox`
swift test
```

## External drives

macOS asks once to let Jukebox read removable volumes. If a track's file is
missing (drive unmounted) it is skipped rather than stalling the queue.

State lives in `~/.jukebox/` (socket, queue, optional debug log with
`JUKEBOX_DEBUG=1`). `brew uninstall --zap --cask mac-jukebox` removes it.

## License

MIT. See [LICENSE](LICENSE).
