---
name: switch-claude-audio-notifications
description: Toggle Claude Code audio notifications (TTS via say + kitty bell) on or off globally. Use when the user wants to silence the spoken hook alerts (e.g., during meetings, calls, focus time) or re-enable them.
---

# Toggle Claude Code audio notifications

This skill flips a sentinel file at `~/.claude/hooks/.disabled`. The hook script `~/.claude/hooks/speak.sh` checks for this file at the top and exits silently if it exists. Toggling takes effect immediately for all subsequent hook events — no session restart needed.

## What to do

Run this bash one-liner:

```bash
F="$HOME/.claude/hooks/.disabled"
if [ -f "$F" ]; then
  rm "$F" && echo "✓ Claude audio notifications ENABLED"
else
  touch "$F" && echo "✗ Claude audio notifications DISABLED"
fi
```

Then report the new state to the user in one short sentence.

## Notes

- The toggle is global across all Claude sessions and projects.
- Logging is also suppressed while disabled (speak.sh exits before writing).
- The user's `~/.claude/settings.json` and `~/.config/claude-audio-hooks/config.json` are not modified.
