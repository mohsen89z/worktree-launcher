# Worktree Launcher

macOS menu bar app and CLI for owning long-running local development processes across repositories and worktrees.

Use it when you want a stable place to register, start, restart, open, inspect logs for, and stop local app stacks without leaving unmanaged terminal processes behind.

## Requirements

- macOS 13+
- Swift 6.1+

## Install

```bash
./scripts/install.sh
```

This installs:

- `~/Applications/Worktree Launcher.app`
- `~/.local/bin/wt-launch`
- a per-user LaunchAgent so the menu bar app starts after login

If macOS requires Login Items approval, open the menu bar app and use its Login Items button.

## Usage

```bash
wt-launch register \
  --name web-app \
  --cwd "$PWD" \
  --command "npm run dev" \
  --url http://localhost:3000 \
  --port 3000 \
  --tag frontend \
  --start

wt-launch list
wt-launch restart web-app
wt-launch open web-app
wt-launch logs web-app --lines 100
wt-launch remove web-app
```

Register a multi-process stack by repeating `--command`, `--web-app`, `--port`, and `--tag`:

```bash
wt-launch register \
  --name local-stack \
  --cwd "$PWD" \
  --command "npm run dev:web" \
  --command "npm run dev:api" \
  --web-app "Web=http://localhost:3000" \
  --web-app "API=http://localhost:4000" \
  --port 3000 \
  --port 4000 \
  --tag full-stack \
  --start
```

## Data

- Registry: `~/Library/Application Support/Worktree Launcher/registry.json`
- Token: `~/Library/Application Support/Worktree Launcher/token`
- Logs: `~/Library/Logs/Worktree Launcher/<record-id>.log`

`remove` deletes launcher metadata only. It does not delete git worktrees or repo files.

## Uninstall

```bash
./scripts/uninstall.sh
```

Add `--purge-data` to remove registry and logs.
