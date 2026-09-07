#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SOURCE="$($ROOT/scripts/build-app.sh | tail -n 1)"
APP_DEST="$HOME/Applications/Worktree Launcher.app"
BIN_DIR="$HOME/.local/bin"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/io.github.mohsen89z.worktree-launcher.plist"
UID_VALUE="$(id -u)"

mkdir -p "$HOME/Applications" "$BIN_DIR" "$LAUNCH_AGENTS"
launchctl bootout "gui/$UID_VALUE" "$PLIST" >/dev/null 2>&1 || true
pkill -x WorktreeLauncherApp >/dev/null 2>&1 || true
sleep 0.2
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"
cp "$ROOT/.build/release/wt-launch" "$BIN_DIR/wt-launch"
chmod +x "$BIN_DIR/wt-launch"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>io.github.mohsen89z.worktree-launcher</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-ga</string>
    <string>$APP_DEST</string>
    <string>--args</string>
    <string>--background</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLIST

open "$APP_DEST"
launchctl bootstrap "gui/$UID_VALUE" "$PLIST" >/dev/null 2>&1 || true
launchctl enable "gui/$UID_VALUE/io.github.mohsen89z.worktree-launcher" >/dev/null 2>&1 || true

echo "Installed $APP_DEST"
echo "Installed $BIN_DIR/wt-launch"
echo "Installed LaunchAgent $PLIST"
