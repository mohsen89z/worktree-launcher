#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build -c release --product WorktreeLauncherApp
swift build -c release --product wt-launch
"$ROOT/scripts/generate-icon.swift" "$ROOT/Resources/AppIcon.icns"

APP_DIR="$ROOT/.build/release/Worktree Launcher.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$ROOT/.build/release/WorktreeLauncherApp" "$MACOS/WorktreeLauncherApp"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
chmod +x "$MACOS/WorktreeLauncherApp"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
