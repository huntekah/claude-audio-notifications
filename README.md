# claude-audio-notifications

Audio notifications for Claude Code on macOS via the hooks system. Hear which project Claude is asking about, get a kitty tab bell glyph for unfocused sessions, and stay silent when the tab is already visible.

## What you hear

By default (voice: `Samantha` — built into every Mac):

| Event | Spoken |
|---|---|
| `Stop` | *"Claude done in {project}"* |
| `Notification` | *"Notification in {project} - {message}"* |
| `PermissionRequest` | *"Permission request in {project} for {tool}"* (debounced; only first of a tool burst) |
| `StopFailure` | *"Stop failure - {error_type}"* |
| `SessionStart` | *"Session resume in {project}"* (silent on fresh launch) |

Silenced automatically when the kitty tab is currently visible (no point announcing what you're staring at). The kitty bell glyph still fires so you can spot which tab triggered the event.

## Prerequisites

- macOS (uses `say` for TTS)
- [kitty](https://sw.kovidgoyal.net/kitty/) terminal with the following in `~/.config/kitty/kitty.conf`:
  ```
  allow_remote_control yes
  listen_on unix:/tmp/kitty-{kitty_pid}
  ```
  Then **fully restart kitty** (not just config reload — `listen_on` is a startup option). The `listen_on` line is required: hook subprocesses don't have a controlling `/dev/tty`, so `kitty @ ls` can't auto-discover the parent kitty via the OSC channel. The socket lets it connect explicitly via `$KITTY_LISTEN_ON`.
- `jq` (`brew install jq`)
- Claude Code 2.x

## Install

```bash
git clone <repo-url> ~/repos/claude-audio-notifications
cd ~/repos/claude-audio-notifications
./install.sh
```

This creates symlinks from `~/.claude/hooks/` and `~/.claude/skills/` into the repo, and seeds `~/.config/claude-audio-hooks/config.json` with the defaults. Then merge `settings-snippet.json` into your `~/.claude/settings.json` and restart Claude sessions.

## Pick your voices

Edit `~/.config/claude-audio-hooks/config.json`. Each event has:

- **`voice`** — passed to `say -v`. Run `say -v '?'` to list installed voices. Download Premium / Siri voices via *System Settings → Accessibility → Spoken Content → System Voice → Manage Voices* for much better quality.
- **`phrase`** — a [jq](https://jqlang.github.io/jq/) expression evaluated against the hook's JSON payload (see [hook events](https://code.claude.com/docs/en/hooks) for the schema per event). Return an empty string to silence that event.
- **`debounce_s`** — sliding-window debounce in seconds. Events fired within this window are silenced. Useful for `PermissionRequest` since Claude often makes 5-10 tool requests in a burst.

Example: different voice per event, all calm Samantha by default.

```json
{
  "events": {
    "Stop":              {"voice": "Samantha", "phrase": "...", "debounce_s": 0},
    "PermissionRequest": {"voice": "Daniel",   "phrase": "...", "debounce_s": 15}
  }
}
```

## Toggle on/off mid-session

From inside Claude Code:

```
/switch-claude-audio-notifications
```

Takes effect on the next hook event — no session restart.

## Inspect the log

Every event writes one JSONL row to `/tmp/claude-hooks.log`:

```bash
# Recent spoken phrases
tail -10 /tmp/claude-hooks.log | jq '{event:.hook_event_name, spoken:._spoken, silenced:._silenced, reason:._silence_reason}'

# Audio timing — did `say` actually run promptly?
jq -c 'select(._wait_to_speak_s != null) | {wait:._wait_to_speak_s, audio:._audio_duration_s, spoken:._spoken}' /tmp/claude-hooks.log

# Focus state at the moment each event fired (race-condition debugging)
jq -c '{spoken:._spoken, my_wid:._diag.my_wid, focused_wid:._diag.focused_window_id, active:._diag.tab_active}' /tmp/claude-hooks.log
```

## How it works

`hooks/speak.sh` (bash, sources `hooks/lib.sh`):
1. Reads hook JSON from stdin.
2. Pulls per-event config (voice, jq phrase template, debounce window) from `~/.config/claude-audio-hooks/config.json`.
3. Queries `kitty @ ls` to check whether our tab is currently visible.
4. Decides whether to speak — silences if phrase is empty, tab is visible, or we're inside the debounce window.
5. Rings `\a` on `/dev/tty` (kitty bell glyph; no-op on active tabs).
6. Speaks via `say -v <voice> "<phrase>"`.
7. Writes a structured log entry with timestamps, focus diagnostics, and silence reason to `/tmp/claude-hooks.log`.

## License

MIT.
