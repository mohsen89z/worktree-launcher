#!/usr/bin/env bash
set -euo pipefail

APP_DEST="$HOME/Applications/Worktree Launcher.app"
BIN_DEST="$HOME/.local/bin/wt-launch"
DATA_DIR="$HOME/Library/Application Support/Worktree Launcher"
LOG_DIR="$HOME/Library/Logs/Worktree Launcher"
PLIST="$HOME/Library/LaunchAgents/io.github.mohsen89z.worktree-launcher.plist"
UID_VALUE="$(id -u)"

launchctl bootout "gui/$UID_VALUE" "$PLIST" >/dev/null 2>&1 || true
osascript -e 'tell application "Worktree Launcher" to quit' >/dev/null 2>&1 || true
rm -rf "$APP_DEST"
rm -f "$BIN_DEST" "$PLIST"

if [[ "${1:-}" == "--purge-data" ]]; then
  rm -rf "$DATA_DIR" "$LOG_DIR"
fi

echo "Uninstalled Worktree Launcher"
