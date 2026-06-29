# kitty-wallbash

Auto-theme your [kitty](https://sw.kovidgoyal.net/kitty/) terminal to match your wallpaper using [HyDE](https://hydeproject.pages.dev/)'s wallbash system.

Every time you switch wallpapers, kitty's colors update automatically.

## Requirements

- [HyDE](https://hydeproject.pages.dev/) with wallbash enabled
- [kitty](https://sw.kovidgoyal.net/kitty/) terminal emulator
- Hyprland (for automatic reloading on wallpaper change)

## Installation

```sh
git clone https://github.com/Hroldddp/kitty-wallbash.git
cd kitty-wallbash
chmod +x install.sh
./install.sh
```

This will:
1. Copy `kitty.dcol` to `~/.config/hyde/wallbash/always/`
2. Remove the static theme include from `~/.config/kitty/kitty.conf`
3. Apply the current wallpaper's colors

## What it does

The wallbash template `kitty.dcol` goes in the `always/` directory, so it runs on **every** wallpaper change and theme switch. It writes wallpaper-derived colors to `~/.config/kitty/theme.conf` and signals kitty to reload.

## Color mapping

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

### Wallbash variable reference

Wallbash extracts 4 color groups from each wallpaper. Each group has:

- `pryX` — primary (dominant) color
- `txtX` — text color (high-contrast inverse of primary)
- `Xxa1` through `Xxa9` — accent colors, from darkest to lightest

Groups 1–3 are typically darker tones; group 4 is the warmest/brightest.

You can edit `~/.config/hyde/wallbash/always/kitty.dcol` to remap any kitty color to a different wallbash variable. See `~/.cache/hyde/wall.dcol` for your current wallpaper's extracted values.

## Uninstall

```sh
rm ~/.config/hyde/wallbash/always/kitty.dcol
```

Then restore kitty's theme include in `~/.config/kitty/kitty.conf` if needed.

## How it works

```
Wallpaper change → wallbash extracts colors → kitty.dcol template
→ sed replaces <wallbash_*> placeholders with hex values
→ writes theme.conf → killall -SIGUSR1 kitty → kitty reloads
```

The template uses HyDE's existing wallbash pipeline — no extra daemons, watchers, or scripts needed.
