#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyde"
HYDE_WALLBASH_DIR="$CONFIG_DIR/hyde/wallbash/always"
HYDE_SCRIPTS_DIR="$CONFIG_DIR/hyde/wallbash/scripts"
KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"
FASTFETCH_CONF="$CONFIG_DIR/fastfetch/config.jsonc"
WALL_SQRE="$CACHE_DIR/wall.sqre"

print_msg()   { printf "\033[1;32m[install]\033[0m %s\n" "$1"; }
print_warn()  { printf "\033[1;33m[warning]\033[0m %s\n" "$1"; }
print_err()   { printf "\033[1;31m[error]\033[0m %s\n" "$1"; }
print_heading() { printf "\n\033[1;36m=== %s ===\033[0m\n" "$1"; }

# ── Prerequisites ─────────────────────────────────────────
check_prerequisites() {
    local fail=0

    if ! command -v kitty &>/dev/null; then
        print_err "kitty terminal is not installed."
        fail=1
    fi

    if [ ! -d "$HYDE_WALLBASH_DIR" ]; then
        print_err "HyDE wallbash directory not found at $HYDE_WALLBASH_DIR"
        print_err "Make sure HyDE is installed and configured."
        fail=1
    fi

    if [ ! -f "$KITTY_CONF" ]; then
        print_err "kitty config not found at $KITTY_CONF"
        fail=1
    fi

    # Create scripts dir if missing (HyDE may not ship it in user config)
    mkdir -p "$HYDE_SCRIPTS_DIR"

    if [ "$fail" -eq 1 ]; then
        exit 1
    fi
    return 0
}

# ── Kitty: wallbash template ──────────────────────────────
install_kitty_template() {
    local src="./config/kitty.dcol"
    local dst="$HYDE_WALLBASH_DIR/kitty.dcol"

    print_msg "Installing kitty wallbash template..."
    cp "$src" "$dst"
    print_msg "  → $dst"
}

patch_kitty_conf() {
    if grep -q "include current-theme.conf" "$KITTY_CONF"; then
        print_msg "Removing static theme include from $KITTY_CONF..."
        sed -i '/^# BEGIN_KITTY_THEME/,/^# END_KITTY_THEME/d' "$KITTY_CONF"
        print_msg "  Done. Wallbash will now control kitty colors."
    else
        print_warn "  Already patched (no static theme include found)."
    fi

    if ! grep -q "include hyde.conf" "$KITTY_CONF"; then
        print_warn "Adding missing 'include hyde.conf' to $KITTY_CONF..."
        echo -e "\ninclude hyde.conf" >>"$KITTY_CONF"
    fi
}

apply_kitty_theme() {
    print_msg "Applying wallpaper colors to kitty..."
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        if command -v "$HOME/.local/lib/hyde/color.set.sh" &>/dev/null; then
            "$HOME/.local/lib/hyde/color.set.sh" "$CACHE_DIR/wall.set" 2>/dev/null
        elif command -v "$HOME/.local/lib/hyde/wallbash.sh" &>/dev/null; then
            "$HOME/.local/lib/hyde/wallbash.sh" "$CACHE_DIR/wall.set" 2>/dev/null
        else
            print_warn "  Could not run wallbash. Run 'hyde-shell reload' or change wallpaper."
        fi
    else
        print_warn "  No Hyprland session. Colors will apply on next wallpaper change."
    fi
}

# ── Dark Reader: wallbash template ────────────────────────
install_darkreader_template() {
    local src="./config/darkreader.dcol"
    local dst_dcol="$HYDE_WALLBASH_DIR/darkreader.dcol"
    local dst_sh="$HYDE_SCRIPTS_DIR/darkreader.sh"

    print_msg "Installing Dark Reader wallbash template..."
    cp "$src" "$dst_dcol"

    # Copy the companion script
    if [ -f "./scripts/darkreader.sh" ]; then
        cp "./scripts/darkreader.sh" "$dst_sh"
        chmod +x "$dst_sh"
    fi

    print_msg "  → $dst_dcol"
    print_msg "  → $dst_sh"
    print_warn "  Dark Reader colors are generated on every wallpaper change,"
    print_warn "  but auto-applying them requires browser integration."
    print_warn "  See README.md for manual import instructions."
}

# ── Fastfetch: wallpaper as terminal logo ─────────────────
patch_fastfetch_logo() {
    if [ ! -f "$FASTFETCH_CONF" ]; then
        print_warn "No fastfetch config found at $FASTFETCH_CONF — skipping logo setup."
        print_warn "Run 'fastfetch --gen-config' first, or use the preset in fastfetch/."
        return
    fi

    if grep -q 'wall.sqre' "$FASTFETCH_CONF" 2>/dev/null; then
        print_warn "  Fastfetch already configured to use wallpaper as logo."
        return
    fi

    # Backup original
    cp "$FASTFETCH_CONF" "${FASTFETCH_CONF}.bak.$(date +%s)"

    # Replace the logo source line
    if grep -q 'hyde-shell fastfetch logo' "$FASTFETCH_CONF" 2>/dev/null; then
        sed -i 's|"source": .*|"source": "$HOME/.cache/hyde/wall.sqre",|' "$FASTFETCH_CONF"
        print_msg "  Fastfetch now uses wallpaper as terminal logo."
    else
        print_warn "  Could not find logo source line in fastfetch config."
        print_warn "  Add manually: \"source\": \"\$HOME/.cache/hyde/wall.sqre\""
    fi

    # Ensure wall.sqre exists
    if [ ! -e "$WALL_SQRE" ]; then
        # Symlink broken — rerun wallbash
        if command -v "$HOME/.local/lib/hyde/wallpaper/cache.sh" &>/dev/null; then
            "$HOME/.local/lib/hyde/wallpaper/cache.sh" commence -w "$CACHE_DIR/wall.set" &>/dev/null || true
        fi
    fi
}

# ── Verify ────────────────────────────────────────────────
verify() {
    local ok=0

    echo ""
    print_heading "Verification"

    if [ -f "$HYDE_WALLBASH_DIR/kitty.dcol" ]; then
        print_msg "  ✅ Kitty template installed"
    else
        print_err "  ❌ Kitty template missing"
        ok=1
    fi

    if [ -f "$HYDE_WALLBASH_DIR/darkreader.dcol" ]; then
        print_msg "  ✅ Dark Reader template installed"
    else
        print_warn "  ⚠️  Dark Reader template missing"
    fi

    if [ -f "$KITTY_CONF" ] && ! grep -q "current-theme.conf" "$KITTY_CONF" 2>/dev/null; then
        print_msg "  ✅ Kitty config patched (no static theme override)"
    fi

    if [ -f "$FASTFETCH_CONF" ] && grep -q 'wall.sqre' "$FASTFETCH_CONF" 2>/dev/null; then
        print_msg "  ✅ Fastfetch configured to show wallpaper"
    fi

    if [ "$ok" -eq 1 ]; then
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────
main() {
    echo "=============================================="
    echo "  Kitty + Dark Reader + Fastfetch Wallbash"
    echo "  Auto-theme your terminal & browser"
    echo "=============================================="

    print_heading "Prerequisites"
    check_prerequisites

    print_heading "Kitty Terminal"
    install_kitty_template
    patch_kitty_conf

    print_heading "Dark Reader"
    install_darkreader_template

    print_heading "Terminal Logo (Fastfetch)"
    patch_fastfetch_logo

    print_heading "Applying"
    apply_kitty_theme

    verify

    echo ""
    print_msg "All done! Change your wallpaper to see everything update."
    print_msg "  • Kitty colors → auto (on wallpaper change)"
    print_msg "  • Terminal logo → always shows current wallpaper"
    print_msg "  • Dark Reader → colors generated, see README for import"
    echo ""
}

main
