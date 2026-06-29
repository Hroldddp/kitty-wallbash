# AGENT.md — kitty-wallbash

## Overview

Auto-theme kitty terminal, Dark Reader browser extension, SDDM login screen, and Fastfetch terminal logo to match the current wallpaper using HyDE's wallbash color extraction system.

## File Layout

```
kitty-wallbash/
├── config/
│   ├── kitty.dcol          # Wallbash template → ~/.config/kitty/theme.conf
│   ├── darkreader.dcol     # Wallbash template → ~/.cache/hyde/wallbash/darkreader.json
│   └── sddm.dcol           # Wallbash template → ~/.cache/hyde/wallbash/sddm.conf
├── scripts/
│   ├── darkreader.sh       # Post-process: generates preset + calls auto-apply
│   ├── darkreader-apply.js # Node.js: writes colors to Brave's LevelDB
│   ├── sddm.sh             # Stages colors+wallpaper, calls root helper via sudo -n
│   ├── sddm-apply-wallbash # Root helper: updates /usr/share/sddm/themes/Candy/theme.conf
│   └── wallbash-check.sh   # Full pipeline diagnostic (20 checks)
├── fastfetch/
│   └── wallpaper-logo.jsonc
├── install.sh              # Single-file installer
├── README.md
└── AGENT.md
```

## Architecture

### Wallbash Pipeline

The `.dcol` files in `config/` are wallbash templates. Each has a header line:

```
<output_file>|<command_to_run_after_writing>
```

HyDE's `fn_wallbash` (in `color.set.sh`) processes every `.dcol` in `~/.config/hyde/wallbash/always/` on each wallpaper change:
1. Reads `~/.cache/hyde/wall.dcol` for extracted color variables
2. Substitutes `<wallbash_*>` placeholders with hex values
3. Writes to the output path
4. Runs the command (typically a companion script)

### SDDM Architecture

3 independent trigger mechanisms (no single point of failure):

```
Mechanism 1 — systemd path watcher (reacts to EVERY wallpaper/theme change):
  ~/.cache/hyde/wall.set changed (inotify)
  → sddm-watch.path fires sddm-watch.service
  → sddm.sh → sudo -n helper → updates Candy theme

Mechanism 2 — Hyprland startup hook:
  Hyprland starts → exec-once in ~/.config/hypr/userprefs.conf
  → sddm.sh → sudo -n helper

Mechanism 3 — wallbash dcol pipeline (passive fallback):
  color.set.sh processes always/*.dcol
  → sddm.dcol writes sddm.conf to cache (output only, no command)
```

`sddm.sh` is self-contained — it reads `wall.dcol` directly and generates colors itself. It does NOT depend on the dcol template output.

Helper flow:
```
sddm.sh (user mode)
  → reads wall.dcol + wall.set.png directly
  → generates sddm-colors.conf in /var/tmp/
  → sudo -n /usr/local/bin/sddm-apply-wallbash <colors> <wallpaper>
       → sed-updates Candy/theme.conf (Background + BackgroundS + 3 colors)
       → copies wallpaper to backgrounds/
```

Key design decisions:
- **`sddm.sh`** reads `wall.dcol` directly — always gets the current wallpaper colors regardless of dcol template state
- **Root helper** validates target path is under `/usr/share/sddm/themes/*` to prevent abuse
- **NOPASSWD sudoers rule** scoped to exactly one binary path
- **`sudo -n`** (non-interactive) — never prompts, never triggers pam_faillock
- **Candy ignores `Background`** — it reads `BackgroundS` (slideshow). Helper sets BOTH.
- **systemd path unit** uses `PathChanged=` on `%h/.cache/hyde/wall.set` — fires on every symlink change

### Dark Reader Architecture

```
darkreader.dcol → ~/.cache/hyde/wallbash/darkreader.json
               → darkreader.sh (post-process)
                    → generates .drconf preset for manual import
                    → calls darkreader-apply.js (Node.js)
                         → writes to Brave's LevelDB (chrome.storage.sync)
```

## Conventions

- **Shell scripts**: `#!/usr/bin/env bash` with `set -euo pipefail` for user scripts; `#!/bin/sh` for the root helper (minimal deps)
- **No comments in code** unless essential
- **Variables**: lowercase_with_underscores for locals, UPPER_CASE for exported/config vars
- **Path vars**: `cacheDir="${cacheDir:-$HOME/.cache/hyde}"` — respect the variable if already set by wallbash
- **Error messages**: prefix with `[wallbash] <component> ::` for easy grepping in logs
- **Exit codes**: 0 success, non-zero failure
- **dcol templates**: first line is `output|command`, remaining lines are the template body using `<wallbash_*>` placeholders

## Important Constraints

1. **`sudo -n` only** in sddm.sh — never `sudo` without `-n`. Interactive sudo in background triggers pam_faillock account lockout.
2. **NOPASSWD rule** must be scoped to exactly one binary path — no wildcards.
3. **Root helper path validation** must check target dir is under `/usr/share/sddm/themes/` to prevent abuse.
4. **Wallbash scripts** should fail gracefully (exit non-zero, print message) rather than hanging or prompting.
5. **dcol templates** are processed by wallbash synchronously — slow commands delay wallpaper switching.
6. **Candy theme.conf** non-color settings (ScreenWidth, FormPosition, Font, blur, etc.) must never be overwritten by the helper — only the 5 theme lines are touched: `Background`, `BackgroundS`, `MainColor`, `AccentColor`, `BackgroundColor`.
7. **Candy ignores `Background`** — `Main.qml:238` reads `config.BackgroundS` (slideshow list) instead. The helper must always update `BackgroundS` to only `backgrounds/wallpaper.png` or the wallpaper won't display.

## Dev Workflow

```bash
# Test install from repo root
bash install.sh

# Run diagnostics
bash ~/.config/hyde/wallbash/scripts/wallbash-check.sh

# Test SDDM pipeline manually
bash ~/.config/hyde/wallbash/scripts/sddm.sh

# Verify SDDM theme
grep -E "^(MainColor|AccentColor|BackgroundColor|Background)=" /usr/share/sddm/themes/Candy/theme.conf

# Test Dark Reader LevelDB (Brave must be closed)
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js

# Check current wallbash colors
cat ~/.cache/hyde/wall.dcol

# Simulate a wallpaper change (reruns all dcol templates)
bash ~/.local/lib/hyde/wallbash.sh ~/.cache/hyde/wall.set
```
