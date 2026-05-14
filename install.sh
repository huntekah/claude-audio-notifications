#!/bin/bash
# install.sh — wire this repo into a user's ~/.claude/ via symlinks
# and seed a default config. Idempotent: safe to run multiple times.

set -e

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
CONFIG_DIR="$HOME/.config/claude-audio-hooks"
HOOKS_DIR="$HOME/.claude/hooks"
SKILL_DIR="$HOME/.claude/skills/switch-claude-audio-notifications"

mkdir -p "$HOOKS_DIR" "$SKILL_DIR" "$CONFIG_DIR"

ln -sfn "$REPO_DIR/hooks/speak.sh" "$HOOKS_DIR/speak.sh"
ln -sfn "$REPO_DIR/hooks/lib.sh" "$HOOKS_DIR/lib.sh"
ln -sfn "$REPO_DIR/skills/switch-claude-audio-notifications/SKILL.md" "$SKILL_DIR/SKILL.md"

if [ ! -f "$CONFIG_DIR/config.json" ]; then
  cp "$REPO_DIR/default-config.json" "$CONFIG_DIR/config.json"
  echo "Seeded config at $CONFIG_DIR/config.json (Samantha voice by default)."
else
  echo "Config already exists at $CONFIG_DIR/config.json — left untouched."
fi

cat <<EOF

Symlinks installed:
  $HOOKS_DIR/speak.sh -> $REPO_DIR/hooks/speak.sh
  $HOOKS_DIR/lib.sh   -> $REPO_DIR/hooks/lib.sh
  $SKILL_DIR/SKILL.md -> $REPO_DIR/skills/switch-claude-audio-notifications/SKILL.md

Next steps:
  1. Pick your voices: edit $CONFIG_DIR/config.json
     (run \`say -v '?'\` to list available voices)
  2. Merge hook entries from settings-snippet.json into ~/.claude/settings.json
  3. Enable kitty remote control: add \`allow_remote_control yes\` to ~/.config/kitty/kitty.conf and restart kitty
  4. Restart your Claude Code sessions
  5. Use /switch-claude-audio-notifications anytime to toggle audio off/on
EOF
