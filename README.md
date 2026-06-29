# kitty-wallbash

Auto-theme your [kitty](https://sw.kovidgoyal.net/kitty/) terminal, your [Dark Reader](https://darkreader.org/) browser extension, and your terminal logo to match your wallpaper using [HyDE](https://hydeproject.pages.dev/)'s wallbash system.

Every time you switch wallpapers, everything updates automatically.

## What's included

| Feature | Description |
|---|---|
| **Kitty terminal** | Background, foreground, cursor, selection, and 16 ANSI colors auto-update on wallpaper change |
| **Dark Reader** | Wallpaper colors auto-apply via LevelDB when Brave is closed (or manually import a preset) |
| **Terminal logo** | Fastfetch always shows your current wallpaper as the terminal splash logo |

## Requirements

- [HyDE](https://hydeproject.pages.dev/) with wallbash enabled
- [kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator
- [fastfetch](https://github.com/fastfetch-cli/fastfetch) (usually included with HyDE)
- Hyprland (for automatic reloading on wallpaper change)
- Brave/Chrome with [Dark Reader](https://darkreader.org/) (optional, for browser theming)

## Installation

```sh
git clone https://github.com/Hroldddp/kitty-wallbash.git
cd kitty-wallbash
chmod +x install.sh
./install.sh
```

This will:
1. Copy `kitty.dcol` → `~/.config/hyde/wallbash/always/` — wallbash template for kitty
2. Copy `darkreader.dcol` → `~/.config/hyde/wallbash/always/` — wallbash template for Dark Reader
3. Copy `darkreader.sh` → `~/.config/hyde/wallbash/scripts/` — post-process script
4. Remove the static theme include from `~/.config/kitty/kitty.conf`
5. Configure fastfetch to use `~/.cache/hyde/wall.sqre` as the logo
6. Apply the current wallpaper's colors

---

## 1. Kitty Terminal

The `kitty.dcol` template goes in `always/`, so it runs on **every** wallpaper change and theme switch. It writes wallpaper-derived colors to `~/.config/kitty/theme.conf` and signals kitty to reload.

### Color mapping

| Kitty setting | Wallbash variable | Description |
|---|---|---|
| `background` | `<wallbash_pry1>` | Primary color — dominant wallpaper color |
| `foreground` | `<wallbash_txt1>` | Text color (inverse of primary) |
| `selection_foreground` | `<wallbash_pry1>` | Selection text — same as background |
| `selection_background` | `<wallbash_txt1>` | Selection bg — same as foreground |
| `cursor` | `<wallbash_4xa5>` | Accent from color group 4 |
| `cursor_text_color` | `<wallbash_txt4>` | Text color for group 4 |
| `color0` / `color8` | `<wallbash_1xa1>` / `<wallbash_1xa4>` | Black / Bright black |
| `color1` / `color9` | `<wallbash_4xa6>` / `<wallbash_4xa8>` | Red / Bright red |
| `color2` / `color10` | `<wallbash_2xa6>` / `<wallbash_2xa8>` | Green / Bright green |
| `color3` / `color11` | `<wallbash_3xa6>` / `<wallbash_3xa8>` | Yellow / Bright yellow |
| `color4` / `color12` | `<wallbash_1xa7>` / `<wallbash_1xa9>` | Blue / Bright blue |
| `color5` / `color13` | `<wallbash_2xa7>` / `<wallbash_2xa9>` | Magenta / Bright magenta |
| `color6` / `color14` | `<wallbash_3xa7>` / `<wallbash_3xa9>` | Cyan / Bright cyan |
| `color7` / `color15` | `<wallbash_4xa6>` / `<wallbash_4xa8>` | White / Bright white |

### How it works

```
Wallpaper change → wallbash extracts colors → kitty.dcol template
→ sed replaces <wallbash_*> placeholders with hex values
→ writes theme.conf → killall -SIGUSR1 kitty → kitty reloads
```

---

## 2. Dark Reader

The `darkreader.dcol` template generates a JSON file at `~/.cache/hyde/wallbash/darkreader.json` with wallpaper-derived colors, plus a `.drconf` preset file.

### Applying to Brave/Chrome

Dark Reader stores colors inside Chromium's sandboxed extension storage (`chrome.storage.sync`), so there's no direct file-to-browser pipeline like kitty. Two options:

#### Option A: Manual import (easy)

1. Open Dark Reader's popup → click the **"More"** tab → **"Dev Tools"**
2. Under **"Color scheme"**, set:
   - **Dark Background**: paste `darkSchemeBackgroundColor` from `~/.cache/hyde/wallbash/darkreader.json`
   - **Dark Text**: paste `darkSchemeTextColor`
   - **Light Background**: paste `lightSchemeBackgroundColor`
   - **Light Text**: paste `lightSchemeTextColor`
3. Run these steps again after each wallpaper change.

#### Option B: Auto-apply via LevelDB (recommended)

The install script sets up automatic Dark Reader color updates using a Node.js script that writes directly to Chromium's LevelDB storage. This works whenever Brave is not running.

**How it works:**

1. On each wallpaper change, wallbash generates `~/.cache/hyde/wallbash/darkreader.json` with the new colors
2. The post-process script `scripts/darkreader.sh` tries to apply them via `scripts/darkreader-apply.js`
3. If Brave is closed, colors are written directly to its extension storage — they'll be active on next launch
4. If Brave is running, colors are saved to a preset file for manual import

**To apply pending colors immediately:**

```sh
# Close Brave first, then:
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js
```

The script writes to `chrome.storage.sync` (and falls back to `chrome.storage.local`), which Dark Reader reads at startup. This is the same mechanism Chromium extensions use internally.

> **Note:** LevelDB doesn't support concurrent access — Brave must be closed for the auto-apply to work. The `install.sh` script installs the `leveldown` Node.js package automatically if Node.js is available.

---

## 3. Terminal always shows wallpaper as logo

Fastfetch is configured to use `~/.cache/hyde/wall.sqre` as its logo source. This is a symlink that HyDE updates on every wallpaper switch — so your terminal splash always shows the current wallpaper.

### Before vs After

```
Before: random logo (distro icon, theme logo, user pic, or wallpaper)
After:  always shows the current wallpaper
```

To revert:

```sh
# Restore the backup created by install.sh
cp ~/.config/fastfetch/config.jsonc.bak.* ~/.config/fastfetch/config.jsonc
```

Or if you just want the preset file:

```sh
fastfetch --config ./fastfetch/wallpaper-logo.jsonc
```

---

## Wallbash variable reference

Wallbash extracts 4 color groups from each wallpaper. Each group has:

| Variable | Description |
|---|---|
| `pryX` | Primary (dominant) color |
| `txtX` | Text color (high-contrast inverse of primary) |
| `Xxa1` through `Xxa9` | Accent colors, darkest → lightest |

Groups 1–3 are typically darker tones; group 4 is the warmest/brightest.

You can edit any `.dcol` template in `~/.config/hyde/wallbash/always/` to remap colors. See `~/.cache/hyde/wall.dcol` for your current wallpaper's extracted values.

## Uninstall

```sh
# Remove templates
rm ~/.config/hyde/wallbash/always/kitty.dcol
rm ~/.config/hyde/wallbash/always/darkreader.dcol
rm ~/.config/hyde/wallbash/scripts/darkreader.sh

# Restore kitty config
# Edit ~/.config/kitty/kitty.conf and add back:
#   include current-theme.conf

# Restore fastfetch config
cp ~/.config/fastfetch/config.jsonc.bak.* ~/.config/fastfetch/config.jsonc
```

## Credits

- [HyDE Project](https://hydeproject.pages.dev/) — the wallbash color extraction system
- [kitty terminal](https://sw.kovidgoyal.net/kitty/) — SIGUSR1 live reload
- [Dark Reader](https://darkreader.org/) — browser dark mode engine
- [ChromiumPywal](https://github.com/metafates/ChromiumPywal) — inspiration for Chrome theming
