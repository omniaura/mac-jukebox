# Agent notes

`jukebox` is built for agents to queue music for a human. Typical use:

```bash
jukebox cue --shuffle --play "/Volumes/Drive/Music"   # queue a folder and start
jukebox status --json                                  # what is playing
jukebox pause | resume | next
```

- Every command prints one result and exits; `--json` gives structured output.
- `cue` resolves relative paths against **your** working directory.
- `cue` is idempotent for tracks still ahead in the queue. Use `jukebox clear`
  first for a fresh playlist.
- Do not blast audio unprompted. Pausing and `jukebox stop` are always safe.
- The app launches itself; if `jukebox status` exits 2, read `~/.jukebox/jukebox.log`.
- Set `JUKEBOX_DEBUG=1` when launching the app to log media-key commands.

## Developing

- `make build`, `swift test`, `make app` (assembles `build/Jukebox.app`).
- Architecture: one binary. With no arguments and no TTY it is the menu bar app
  (`App.swift`, `Engine.swift`); otherwise it is the CLI (`CLI.swift`). They talk
  JSON over a Unix socket at `~/.jukebox/jukebox.sock` (`Socket.swift`,
  `Handler.swift`). The engine is main-thread only.
- Releases: push a `vX.Y.Z` tag. See [RELEASING.md](RELEASING.md).
