#!/bin/bash
# ~/.claude/hooks/lib.sh
# Shared helpers for Claude Code audio hooks. Source from hook scripts:
#   source "$HOME/.claude/hooks/lib.sh"

HOOK_LOG=/tmp/claude-hooks.log
HOOK_DEBOUNCE_DIR=/tmp/claude-hooks-debounce

# hook_now
# Echoes current epoch time as float (sub-second precision) via jq.
hook_now() { jq -n 'now'; }

# hook_debounce_check_and_mark <session_id> <event_name> <window_seconds>
# Sliding-window debounce: touches the marker file on EVERY call so a stream
# of events stays silenced. First call (or first after a `window`-second
# quiet period) returns 1 (speak); subsequent rapid calls return 0 (silence).
# Returns 1 immediately if window is unset or 0.
hook_debounce_check_and_mark() {
  local sid=$1 event=$2 window=$3
  [ -z "$window" ] || [ "$window" = "0" ] && return 1

  mkdir -p "$HOOK_DEBOUNCE_DIR" 2>/dev/null
  local f="$HOOK_DEBOUNCE_DIR/${sid}-${event}"

  local prev=0
  [ -f "$f" ] && prev=$(stat -f %m "$f" 2>/dev/null || echo 0)
  touch "$f"

  local age=$(( $(date +%s) - prev ))
  [ "$age" -lt "$window" ]  # 0 (true) means in window → debounce
}

# hook_focus_diag <kitty_window_id>
# Echoes a JSON object describing the current kitty focus state relative to
# the given window. Used to diagnose refocus races.
hook_focus_diag() {
  local wid=$1
  local ls_result

  if [ -z "$wid" ] || [ "$wid" = "0" ] || ! command -v kitty >/dev/null 2>&1; then
    printf '{"kitty_query_ok":false,"reason":"no_kitty"}'
    return
  fi

  ls_result=$(kitty @ ls 2>/dev/null)
  if [ -z "$ls_result" ]; then
    printf '{"kitty_query_ok":false,"reason":"ls_failed","my_wid":%s}' "$wid"
    return
  fi

  printf '%s' "$ls_result" | jq -c --argjson wid "$wid" '
    . as $os_windows
    | (first(.[] | select(.tabs[]?.windows[]?.id == $wid)) // null) as $my_os
    | (if $my_os then (first($my_os.tabs[] | select(.windows[]?.id == $wid)) // null) else null end) as $my_tab
    | {
        kitty_query_ok: true,
        my_wid: $wid,
        my_os_wid: ($my_os.id // null),
        my_tab_id: ($my_tab.id // null),
        os_window_focused: ($my_os.is_focused // false),
        tab_focused_within_os_window: ($my_tab.is_focused // false),
        tab_active: (($my_os.is_focused // false) and ($my_tab.is_focused // false)),
        os_window_count: ($os_windows | length),
        tab_count_in_my_os_window: (($my_os.tabs // []) | length),
        focused_os_wid: ((first(.[] | select(.is_focused)) | .id) // null),
        focused_tab_id: ((first(.[] | select(.is_focused) | .tabs[] | select(.is_focused)) | .id) // null),
        focused_window_id: ((first(.[] | select(.is_focused) | .tabs[] | select(.is_focused) | .windows[] | select(.is_focused)) | .id) // null)
      }
  ' 2>/dev/null || printf '{"kitty_query_ok":false,"reason":"jq_failed","my_wid":%s}' "$wid"
}

# hook_log_event <input_json> <meta_json>
# Merges meta into the payload and appends one JSONL row to $HOOK_LOG.
hook_log_event() {
  local payload=$1 meta=$2
  printf '%s' "$payload" | jq -c --argjson m "$meta" '. + $m' >> "$HOOK_LOG"
}
