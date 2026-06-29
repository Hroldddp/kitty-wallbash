# kitty-wallbash

Auto-theme your [kitty](https://sw.kovidgoyal.net/kitty/) terminal, your [Dark Reader](https://darkreader.org/) browser extension, your [SDDM](https://github.com/sddm/sddm) login screen, and your terminal logo to match your wallpaper using [HyDE](https://hydeproject.pages.dev/)'s wallbash system.

Every time you switch wallpapers, everything updates automatically.

## What's included

| Feature | Description |
|---|---|
| **Kitty terminal** | Background, foreground, cursor, selection, and 16 ANSI colors auto-update on wallpaper change |
| **Dark Reader** | Wallpaper colors auto-apply via LevelDB when Brave is closed (or manually import a preset) |
| **Terminal logo** | Fastfetch always shows your current wallpaper as the terminal splash logo |
| **SDDM login screen** | Login screen background and accent colors match your wallpaper |

## Requirements

- [HyDE](https://hydeproject.pages.dev/) with wallbash enabled
- [kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator
- [fastfetch](https://github.com/fastfetch-cli/fastfetch) (usually included with HyDE)
- Hyprland (for automatic reloading on wallpaper change)
- [SDDM](https://github.com/sddm/sddm) with [Candy theme](https://github.com/JaKooLit/JaKooLit-SDDM-Candy) at `/usr/share/sddm/themes/Candy/` (optional, for login screen)
- Brave/Chrome with [Dark Reader](https://darkreader.org/) (optional, for browser theming)
- Node.js 18+ (optional, for Dark Reader auto-apply)

## Installation

```sh
git clone https://github.com/Hroldddp/kitty-wallbash.git
cd kitty-wallbash
chmod +x install.sh
./install.sh
```

Re-run `./install.sh` after updating HyDE to refresh the version snapshot. Use `./install.sh --force` to reinstall npm dependencies.

### What gets installed

| File | Destination | Purpose |
|---|---|---|
| `config/kitty.dcol` | `~/.config/hyde/wallbash/always/` | Wallbash template for kitty colors |
| `config/darkreader.dcol` | `~/.config/hyde/wallbash/always/` | Wallbash template for Dark Reader colors |
| `config/sddm.dcol` | `~/.config/hyde/wallbash/always/` | Wallbash template for SDDM login colors |
| `scripts/darkreader.sh` | `~/.config/hyde/wallbash/scripts/` | Post-process: generates preset + calls auto-apply |
| `scripts/darkreader-apply.js` | `~/.config/hyde/wallbash/scripts/` | Writes colors to Brave's LevelDB storage |
| `scripts/sddm.sh` | `~/.config/hyde/wallbash/scripts/` | Stages colors + wallpaper, calls root helper via `sudo -n` |
| `scripts/sddm-apply-wallbash` | `/usr/local/bin/` | Root helper: updates Candy theme.conf + copies wallpaper |
| `scripts/wallbash-check.sh` | `~/.config/hyde/wallbash/scripts/` | Diagnostic: check the whole pipeline |
| `leveldown` | `~/.local/share/kitty-wallbash/node_modules/` | Node.js LevelDB bindings (npm) |
| `hyde-version.txt` | `~/.local/share/kitty-wallbash/` | HyDE version snapshotted at install time |
| `/etc/sudoers.d/sddm-wallbash` | — | NOPASSWD sudo rule for `sddm-apply-wallbash` only |

Also patches `~/.config/kitty/kitty.conf` and `~/.config/fastfetch/config.jsonc` as needed. Installs NOPASSWD sudo rule for the SDDM helper.

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

The `darkreader.dcol` template generates a JSON file at `~/.cache/hyde/wallbash/darkreader.json` with wallpaper-derived colors, plus a `.drconf` preset file. The companion script `darkreader-apply.js` writes those colors directly into Brave's extension storage.

### Applying to Brave/Chrome

#### Option A: Auto-apply via LevelDB (recommended)

The install script sets up automatic Dark Reader color updates using a Node.js script that writes directly to Chromium's LevelDB storage.

**How it works:**

1. On each wallpaper change, wallbash generates `~/.cache/hyde/wallbash/darkreader.json` with the new colors
2. The post-process script `scripts/darkreader.sh` tries to apply them via `scripts/darkreader-apply.js`
3. If Brave is closed, colors are written directly to `chrome.storage.sync` — they'll be active on next launch
4. If Brave is running, colors are saved to a preset file for manual import

**To apply pending colors immediately:**

```sh
# Close Brave first, then:
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js
```

**To inspect what's currently stored:**

```sh
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js --check
```

This prints Dark Reader's version, scheme version, and all stored color values.

> **Note:** LevelDB doesn't support concurrent access — Brave must be closed for the auto-apply. The `install.sh` script installs the `leveldown` Node.js package automatically if Node.js is available.

#### Option B: Manual import

1. Open Dark Reader's popup → click the **"More"** tab → **"Dev Tools"**
2. Under **"Color scheme"**, set:
   - **Dark Background**: paste `darkSchemeBackgroundColor` from `~/.cache/hyde/wallbash/darkreader.json`
   - **Dark Text**: paste `darkSchemeTextColor`
   - **Light Background**: paste `lightSchemeBackgroundColor`
   - **Light Text**: paste `lightSchemeTextColor`
3. Run these steps again after each wallpaper change.

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

Or use the standalone preset:

```sh
fastfetch --config ./fastfetch/wallpaper-logo.jsonc
```

---

## 4. SDDM Login Screen

The `sddm.dcol` template generates color values at `~/.cache/hyde/wallbash/sddm.conf` on every wallpaper change. The companion `sddm.sh` script copies the colors + wallpaper to `/var/tmp/` and runs the root helper via `sudo -n`.

**No password prompts** — `install.sh` creates a NOPASSWD sudoers rule scoped to only `/usr/local/bin/sddm-apply-wallbash`.

**Applies on every login** — `install.sh` adds an `exec-once` to `~/.config/hypr/userprefs.conf` so `sddm.sh` runs on every Hyprland startup. This ensures the SDDM theme always reflects the wallpaper that was active when you last logged in.

### How it works

```
Wallpaper change → wallbash extracts colors → sddm.dcol template
→ writes sddm.conf → sddm.sh copies files to /var/tmp/
→ sudo -n sddm-apply-wallbash → sed-updates Candy/theme.conf
→ copies wallpaper to backgrounds/ → SDDM picks it up on next boot
```

### Candy theme.conf — what gets updated

Only these 5 lines are ever changed by the helper (all other settings like font, form position, blur radius are preserved):

| Setting | Source | Description |
|---|---|---|
| `Background` | `wall.set.png` | Lock screen wallpaper |
| `BackgroundS` | `wall.set.png` | Slideshow list — Candy only reads this, not `Background` |
| `MainColor` | `<wallbash_txt1>` | Text color |
| `AccentColor` | `<wallbash_1xa5>` | Accent for inputs and highlights |
| `BackgroundColor` | `<wallbash_pry1>` | Panel/form background |

**Important:** Candy's `Main.qml` reads `BackgroundS` (the slideshow), not `Background`. The helper replaces the entire `BackgroundS` list with just your wallpaper so it always shows. See `Main.qml:238`.

### Verify

```sh
grep -E "^MainColor=|^AccentColor=|^BackgroundColor=|^Background=" /usr/share/sddm/themes/Candy/theme.conf
```

---

## 5. Diagnostics

Two tools to verify everything is working:

### Full pipeline check

```sh
bash ~/.config/hyde/wallbash/scripts/wallbash-check.sh
```

Checks: all templates installed, wallbash engine still processes `always/` files, variable naming convention matches, SDDM theme.conf, LevelDB health, kitty config, fastfetch logo.

### Dark Reader LevelDB check

```sh
node ~/.config/hyde/wallbash/scripts/darkreader-apply.js --check
```

Prints Dark Reader version, scheme version, and all currently stored color values. Confirms all expected fields are present.

---

## 6. Wallbash variable reference

Wallbash extracts 4 color groups from each wallpaper. Each group has:

| Variable | Description |
|---|---|
| `pryX` | Primary (dominant) color |
| `txtX` | Text color (high-contrast inverse of primary) |
| `Xxa1` through `Xxa9` | Accent colors, darkest → lightest |

Groups 1–3 are typically darker tones; group 4 is the warmest/brightest.

You can edit any `.dcol` template in `~/.config/hyde/wallbash/always/` to remap colors. See `~/.cache/hyde/wall.dcol` for your current wallpaper's extracted values.

### All valid placeholders

Templates support these wallbash variables (wallbash replaces them at runtime):

- `<wallbash_mode>` — `light` or `dark`
- `<wallbash_pry1>` through `<wallbash_pry4>` — primary hex colors
- `<wallbash_txt1>` through `<wallbash_txt4>` — text hex colors
- `<wallbash_{i}xa{1-9}>` — 36 accent hex colors (4 groups × 9 shades)
- `_rgba(alpha)` and `_rgb` variants for all hex variables above
- `<<HOME>>` — expands to `$HOME`

## 7. Uninstall

```sh
# Remove wallbash templates
rm ~/.config/hyde/wallbash/always/kitty.dcol
rm ~/.config/hyde/wallbash/always/darkreader.dcol
rm ~/.config/hyde/wallbash/always/sddm.dcol

# Remove scripts
rm ~/.config/hyde/wallbash/scripts/darkreader.sh
rm ~/.config/hyde/wallbash/scripts/darkreader-apply.js
rm ~/.config/hyde/wallbash/scripts/sddm.sh
rm ~/.config/hyde/wallbash/scripts/wallbash-check.sh

# Remove SDDM root helper, sudoers rule, and startup hook
sudo rm /usr/local/bin/sddm-apply-wallbash
sudo rm /etc/sudoers.d/sddm-wallbash
sed -i '/^# wallbash SDDM$/,+1d' ~/.config/hypr/userprefs.conf

# Remove npm dependencies
rm -rf ~/.local/share/kitty-wallbash

# Restore kitty config
# Edit ~/.config/kitty/kitty.conf and add back:
#   include current-theme.conf

# Restore fastfetch config
ls -t ~/.config/fastfetch/config.jsonc.bak.* | head -1 | xargs -r cp {} ~/.config/fastfetch/config.jsonc
```

## 8. Credits

- [HyDE Project](https://hydeproject.pages.dev/) — the wallbash color extraction system
- [kitty terminal](https://sw.kovidgoyal.net/kitty/) — SIGUSR1 live reload
- [Dark Reader](https://darkreader.org/) — browser dark mode engine
- [ChromiumPywal](https://github.com/metafates/ChromiumPywal) — inspiration for Chrome theming
