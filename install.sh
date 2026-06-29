#!/usr/bin/env bash
set -euo pipefail

HYDE_WALLBASH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hyde/wallbash/always"
KITTY_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
KITTY_TEMPLATE_SRC="./config/kitty.dcol"
KITTY_TEMPLATE_DST="$HYDE_WALLBASH_DIR/kitty.dcol"

print_msg() { printf "\033[1;32m[install]\033[0m %s\n" "$1"; }
print_warn() { printf "\033[1;33m[warning]\033[0m %s\n" "$1"; }
print_err() { printf "\033[1;31m[error]\033[0m %s\n" "$1"; }

check_prerequisites() {
    if ! command -v kitty &>/dev/null; then
        print_err "kitty terminal is not installed."
        exit 1
    fi
    if [ ! -d "$HYDE_WALLBASH_DIR" ]; then
        print_err "HyDE wallbash directory not found at $HYDE_WALLBASH_DIR"
        print_err "Make sure HyDE is installed and configured."
        exit 1
    fi
    if [ ! -f "$KITTY_CONF" ]; then
        print_err "kitty config not found at $KITTY_CONF"
        exit 1
    fi
}

install_template() {
    print_msg "Installing kitty wallbash template..."
    cp "$KITTY_TEMPLATE_SRC" "$KITTY_TEMPLATE_DST"
    print_msg "Template installed to $KITTY_TEMPLATE_DST"
}

patch_kitty_conf() {
    if grep -q "include current-theme.conf" "$KITTY_CONF"; then
        print_msg "Removing static theme include from $KITTY_CONF..."
        sed -i '/^# BEGIN_KITTY_THEME/,/^# END_KITTY_THEME/d' "$KITTY_CONF"
        print_msg "Removed static theme include. Wallbash will now control kitty colors."
    else
        print_warn "No static theme include found in $KITTY_CONF - already patched."
    fi

    if ! grep -q "include hyde.conf" "$KITTY_CONF"; then
        print_warn "hyde.conf include not found in $KITTY_CONF. Adding it..."
        echo -e "\ninclude hyde.conf" >>"$KITTY_CONF"
    fi
}

apply_theme() {
    print_msg "Applying wallpaper colors to kitty..."
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        if command -v "$HOME/.local/lib/hyde/color.set.sh" &>/dev/null; then
            "$HOME/.local/lib/hyde/color.set.sh" "$HOME/.cache/hyde/wall.set" 2>/dev/null
        elif command -v "$HOME/.local/lib/hyde/wallbash.sh" &>/dev/null; then
            "$HOME/.local/lib/hyde/wallbash.sh" "$HOME/.cache/hyde/wall.set" 2>/dev/null
        else
            print_warn "Could not run wallbash automatically."
            print_warn "Change your wallpaper or run: hyde-shell reload"
        fi
    else
        print_warn "Hyprland session not detected. Colors will apply on next wallpaper change."
    fi
}

verify() {
    if [ -f "$KITTY_TEMPLATE_DST" ]; then
        print_msg "Setup complete! Your kitty terminal will now automatically match your wallpaper."
        print_msg "  Template: $KITTY_TEMPLATE_DST"
        print_msg "  Changes take effect on every wallpaper switch."
    else
        print_err "Something went wrong - template not found at $KITTY_TEMPLATE_DST"
        exit 1
    fi
}

main() {
    echo "=========================================="
    echo "  Kitty Wallbash - Auto-Theme Installer"
    echo "=========================================="
    echo ""

    check_prerequisites
    install_template
    patch_kitty_conf
    apply_theme
    verify
}

main
