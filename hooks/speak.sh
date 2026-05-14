#!/bin/bash
# speak.sh — Claude Code audio + bell hook.
# Reads hook JSON from stdin, looks up per-event config in $CONFIG_FILE,
# speaks via `say`, rings the kitty bell, and logs to /tmp/claude-hooks.log.
#
# Settings.json command is identical for every hook event:
#   "command": "$HOME/.claude/hooks/speak.sh"
# This script reads .hook_event_name from the payload and dispatches.

source "$(dirname "$0")/lib.sh"

CONFIG_FILE="${CLAUDE_AUDIO_HOOKS_CONFIG:-$HOME/.config/claude-audio-hooks/config.json}"

# Global kill switch — toggled by /switch-claude-audio-notifications skill.
if [ -f "$HOME/.claude/hooks/.disabled" ]; then
  cat >/dev/null
  exit 0
fi

T_RECEIVED=$(hook_now)
INPUT=$(cat)
EVENT_NAME=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""')

[ ! -f "$CONFIG_FILE" ] && exit 0

CONFIG=$(jq -c --arg e "$EVENT_NAME" '.events[$e] // null' "$CONFIG_FILE" 2>/dev/null)
[ "$CONFIG" = "null" ] || [ -z "$CONFIG" ] && exit 0

VOICE=$(printf '%s' "$CONFIG" | jq -r '.voice // "Samantha"')
EXPR=$(printf '%s' "$CONFIG" | jq -r '.phrase // ""')
DEBOUNCE_S=$(printf '%s' "$CONFIG" | jq -r '.debounce_s // 0')

PHRASE=$(printf '%s' "$INPUT" | jq -r "$EXPR" 2>/dev/null)
DIAG=$(hook_focus_diag "${KITTY_WINDOW_ID:-0}")
TAB_ACTIVE=$(printf '%s' "$DIAG" | jq -r '.tab_active // false')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "global"')

silenced=false
reason=""
if [ -z "$PHRASE" ]; then
  silenced=true; reason="empty_phrase"
elif [ "$TAB_ACTIVE" = "true" ]; then
  silenced=true; reason="tab_active"
elif hook_debounce_check_and_mark "$SESSION_ID" "$EVENT_NAME" "$DEBOUNCE_S"; then
  silenced=true; reason="debounced"
fi

[ -n "$PHRASE" ] && printf '\a' > /dev/tty 2>/dev/null

T_SAY_START=null
T_SAY_END=null
if [ "$silenced" != "true" ]; then
  T_SAY_START=$(hook_now)
  say -v "$VOICE" "$PHRASE"
  T_SAY_END=$(hook_now)
fi

META=$(jq -n \
  --arg p "$PHRASE" \
  --arg v "$VOICE" \
  --argjson silenced "$silenced" \
  --arg r "$reason" \
  --argjson d "$DIAG" \
  --argjson pid "$$" \
  --argjson t_received "$T_RECEIVED" \
  --argjson t_say_start "$T_SAY_START" \
  --argjson t_say_end "$T_SAY_END" \
  --argjson debounce_s "$DEBOUNCE_S" \
  '{
    _ts: now,
    _spoken: $p,
    _voice: $v,
    _silenced: $silenced,
    _silence_reason: $r,
    _pid: $pid,
    _debounce_window_s: $debounce_s,
    _t_received: $t_received,
    _t_say_start: $t_say_start,
    _t_say_end: $t_say_end,
    _wait_to_speak_s: (if $t_say_start then ($t_say_start - $t_received) else null end),
    _audio_duration_s: (if ($t_say_start and $t_say_end) then ($t_say_end - $t_say_start) else null end),
    _total_s: (now - $t_received),
    _diag: $d
  }')

hook_log_event "$INPUT" "$META"
