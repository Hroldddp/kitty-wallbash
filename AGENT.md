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

```
sddm.dcol → ~/.cache/hyde/wallbash/sddm.conf
         → sddm.sh (user mode)
              → copies sddm.conf + wall.set.png to /var/tmp/
              → sudo -n /usr/local/bin/sddm-apply-wallbash <colors> <wallpaper>
                   → sed-updates /usr/share/sddm/themes/Candy/theme.conf
                   → copies wallpaper to backgrounds/
```

Key design decisions:
- **User script** (`sddm.sh`) runs as `$USER`, copies files to world-readable `/var/tmp/`
- **Root helper** (`sddm-apply-wallbash`) does the privileged writes, validates target path is under `/usr/share/sddm/themes/*`
- **NOPASSWD sudoers rule** created by `install.sh` at `/etc/sudoers.d/sddm-wallbash`, scoped to only the helper binary
- **`sudo -n`** (non-interactive) — never prompts, never triggers pam_faillock in headless execution
- **Startup hook** — `install.sh` adds `exec-once = bash .../sddm.sh` to `~/.config/hypr/userprefs.conf` so SDDM colors update on every Hyprland login

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
6. **Candy theme.conf** non-color settings (ScreenWidth, FormPosition, Font, blur, etc.) must never be overwritten by the helper — only the 4 color/background lines.

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
