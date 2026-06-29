# AGENT.md — kitty-wallbash

## Overview

Auto-theme kitty terminal, Dark Reader browser extension, SDDM login screen, and Fastfetch terminal logo to match the current wallpaper using HyDE's wallbash color extraction system.

## File Layout

```
kitty-wallbash/
├── config/
│   ├── kitty.dcol                    # Wallbash template → ~/.config/kitty/theme.conf
│   ├── darkreader.dcol               # Wallbash template → ~/.cache/hyde/wallbash/darkreader.json
│   ├── sddm.dcol                     # Wallbash template → ~/.cache/hyde/wallbash/sddm.conf
│   ├── sddm-watch.path               # Systemd USER path watcher (in-session wallpaper changes)
│   ├── sddm-watch.service            # Systemd USER service called by path watcher
│   └── sddm-wallpaper-boot.service   # Systemd SYSTEM service (runs before SDDM at boot)
├── scripts/
│   ├── darkreader.sh       # Post-process: generates preset + calls auto-apply
│   ├── darkreader-apply.js # Node.js: writes colors to Brave's LevelDB
│   ├── sddm.sh             # User-mode: reads wall.dcol, calls helper via sudo -n
│   ├── sddm-apply-wallbash # Root helper: updates Candy theme.conf + copies wallpaper
│   ├── sddm-boot-apply     # Boot-time script (runs as root before SDDM)
│   └── wallbash-check.sh   # Full pipeline diagnostic (28 checks)
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

4 independent trigger mechanisms — NO hardcoded filenames. Every wallpaper/theme change uses the ORIGINAL filename (e.g., `car.png`, `Wallpaper.jpg`).

```
Mechanism 1 — systemd BOOT service (runs BEFORE SDDM at startup):
  multi-user.target → sddm-wallpaper-boot.service (root)
  → reads ~hroldddp/.cache/hyde/wall.set symlink to get original filename
  → reads wall.dcol + wall.set.png
  → copies to Candy/backgrounds/<original_name>
  → updates theme.conf dynamically
  → SDDM starts AFTER and picks up the current wallpaper

Mechanism 2 — systemd path watcher (reacts to in-session wallpaper changes):
  ~/.cache/hyde/wall.set changed (inotify)
  → sddm-watch.path fires sddm-watch.service
  → sddm.sh → sudo -n helper → updates Candy theme

Mechanism 3 — Hyprland startup hook:
  Hyprland starts → exec-once in ~/.config/hypr/userprefs.conf
  → sddm.sh → sudo -n helper

Mechanism 4 — wallbash dcol pipeline (passive fallback):
  color.set.sh processes always/*.dcol
  → sddm.dcol writes sddm.conf to cache (output only, no command)
```

`sddm.sh` and `sddm-boot-apply` are self-contained — they read `wall.dcol` directly and generate colors themselves. No dependency on dcol template output.

Helper flow:
```
sddm.sh (user mode)
  → reads wall.dcol + wall.set.png + wall.set symlink
  → extracts original wallpaper basename (e.g., "car.png")
  → generates sddm-colors.conf in /var/tmp/
  → sudo -n /usr/local/bin/sddm-apply-wallbash <colors> <wallpaper> <basename>
       → sed-updates Candy/theme.conf (Background + BackgroundS + 3 colors)
       → copies wallpaper to backgrounds/<basename>

sddm-boot-apply (root, runs before SDDM)
  → same as above but runs as root directly (no sudo needed)
  → installed at /usr/local/bin/sddm-boot-apply
  → called by sddm-wallpaper-boot.service
```

Key design decisions:
- **NO hardcoded filenames** — helper uses the original wallpaper's basename for Background/BackgroundS
- **`sddm.sh`** reads `wall.dcol` directly — always gets the current wallpaper colors regardless of dcol template state
- **Boot service** runs as `Before=sddm.service` — wallpaper is applied before the login screen appears
- **Root helper** validates target path is under `/usr/share/sddm/themes/*` to prevent abuse
- **NOPASSWD sudoers rule** scoped to exactly one binary path
- **`sudo -n`** (non-interactive) — never prompts, never triggers pam_faillock
- **Candy ignores `Background`** — it reads `BackgroundS` (slideshow). Helper sets BOTH.
- **systemd path unit** uses `PathChanged=` on `%h/.cache/hyde/wall.set` — fires on every symlink change
- **Old wallpaper.png auto-cleaned** — helper and boot script delete it if present

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
7. **Candy ignores `Background`** — `Main.qml:238` reads `config.BackgroundS` (slideshow list) instead. `BackgroundS` must ONLY contain the current wallpaper (single entry, not a list), so SDDM shows only the current wallpaper.
8. **No hardcoded filenames** — helper and boot script derive the destination filename from the original wallpaper's basename (via `readlink -f wall.set`). Never hardcode `wallpaper.png` or any specific name.

## Dev Workflow

```bash
# Test install from repo root
bash install.sh

# Run diagnostics
bash ~/.config/hyde/wallbash/scripts/wallbash-check.sh

# Test SDDM pipeline manually
bash ~/.config/hyde/wallbash/scripts/sddm.sh

# Verify SDDM theme (no hardcoded wallpaper.png — shows original filename)
grep -E "^(MainColor|AccentColor|BackgroundColor|BackgroundS?)=" /usr/share/sddm/themes/Candy/theme.conf

# Test boot script manually (dry run, needs root)
echo 23044213 | sudo -S /usr/local/bin/sddm-boot-apply

# Check boot service status
systemctl status sddm-wallpaper-boot.service

# Test Dark Reader LevelDB (Brave must be closed)
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js

# Check current wallbash colors
cat ~/.cache/hyde/wall.dcol

# Simulate a wallpaper change (reruns all dcol templates)
bash ~/.local/lib/hyde/wallbash.sh ~/.cache/hyde/wall.set
```
