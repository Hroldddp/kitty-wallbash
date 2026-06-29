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
print_ok()    { printf "\033[1;32m  ✅\033[0m %s\n" "$1"; }
print_skip()  { printf "\033[1;33m  ⚠️\033[0m %s\n" "$1"; }
print_action(){ printf "\033[1;36m  →\033[0m %s\n" "$1"; }

SDDM_HELPER="/usr/local/bin/sddm-apply-wallbash"
SDDM_SUDOERS="/etc/sudoers.d/sddm-wallbash"
HYPR_USERPREFS="$CONFIG_DIR/hypr/userprefs.conf"
SDDM_EXEC_ONCE_LINE="# wallbash SDDM"
SDDM_EXEC_ONCE_CMD="exec-once = bash ${HYDE_SCRIPTS_DIR}/sddm.sh"

LIBS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-wallbash"
SNAPSHOT_FILE="$LIBS_DIR/hyde-version.txt"
FORCE_REINSTALL=false

# Parse args
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE_REINSTALL=true ;;
        --help|-h)
            echo "Usage: bash install.sh [OPTIONS]"
            echo ""
            echo "Install or update kitty-wallbash components."
            echo ""
            echo "Options:"
            echo "  -f, --force    Reinstall npm dependencies even if already present"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "Re-run after HyDE updates to refresh the version snapshot."
            exit 0
            ;;
    esac
done

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

    if ! command -v node &>/dev/null; then
        print_warn "Node.js not found - Dark Reader auto-apply will be unavailable"
    fi

    if [ "$fail" -eq 1 ]; then
        exit 1
    fi
    return 0
}

snapshot_hyde_version() {
    mkdir -p "$LIBS_DIR"
    local version_file="$HOME/.local/state/hyde/version"
    if [ -f "$version_file" ]; then
        local ver
        ver=$(grep -oP "HYDE_VERSION='\K[^']+" "$version_file" 2>/dev/null || echo "unknown")
        local branch
        branch=$(grep -oP "HYDE_BRANCH='\K[^']+" "$version_file" 2>/dev/null || echo "unknown")
        echo "HyDE $ver ($branch)" > "$SNAPSHOT_FILE"
        print_msg "  HyDE version snapshotted: HyDE $ver ($branch)"
    else
        echo "unknown" > "$SNAPSHOT_FILE"
        print_warn "  Could not read HyDE version"
    fi
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
    local src_dcol="./config/darkreader.dcol"
    local dst_dcol="$HYDE_WALLBASH_DIR/darkreader.dcol"
    local dst_sh="$HYDE_SCRIPTS_DIR/darkreader.sh"
    local src_js="./scripts/darkreader-apply.js"
    local dst_js="$HYDE_SCRIPTS_DIR/darkreader-apply.js"

    print_msg "Installing Dark Reader wallbash template..."
    cp "$src_dcol" "$dst_dcol"
    print_msg "  → $dst_dcol"

    # Copy the shell companion script
    if [ -f "./scripts/darkreader.sh" ]; then
        cp "./scripts/darkreader.sh" "$dst_sh"
        chmod +x "$dst_sh"
        print_msg "  → $dst_sh"
    fi

    # Copy the Node.js LevelDB apply script
    if [ -f "$src_js" ]; then
        cp "$src_js" "$dst_js"
        chmod +x "$dst_js"
        print_msg "  → $dst_js"
    fi

    # Copy diagnostic script
    if [ -f "./scripts/wallbash-check.sh" ]; then
        cp "./scripts/wallbash-check.sh" "$HYDE_SCRIPTS_DIR/wallbash-check.sh"
        chmod +x "$HYDE_SCRIPTS_DIR/wallbash-check.sh"
        print_msg "  → $HYDE_SCRIPTS_DIR/wallbash-check.sh"
    fi

    # Install leveldown for Node.js DB access
    if command -v node &>/dev/null; then
        if [ "$FORCE_REINSTALL" = true ] || [ ! -d "$LIBS_DIR/node_modules/leveldown" ]; then
            print_msg "Installing leveldown (Node.js LevelDB bindings)..."
            mkdir -p "$LIBS_DIR"
            if npm install --prefix "$LIBS_DIR" leveldown &>/dev/null; then
                print_msg "  leveldown installed"
            else
                print_warn "  leveldown install failed - auto-apply unavailable"
            fi
        else
            print_msg "  leveldown already installed"
        fi
    else
        print_warn "  Node.js not found - auto-apply unavailable"
    fi

    print_warn "  Dark Reader auto-apply works when Brave is closed."
    print_warn "  Close Brave to apply, or import the preset manually."
}

# ── SDDM: wallbash colors for login screen ────────────────
install_sddm() {
    if ! command -v sddm &>/dev/null; then
        print_skip "SDDM not installed — skipping login screen theming."
        print_skip "  Install sddm then re-run install.sh to enable."
        return
    fi

    local src_dcol="./config/sddm.dcol"
    local dst_dcol="$HYDE_WALLBASH_DIR/sddm.dcol"
    local src_sh="./scripts/sddm.sh"
    local dst_sh="$HYDE_SCRIPTS_DIR/sddm.sh"
    local src_helper="./scripts/sddm-apply-wallbash"

    print_msg "Installing SDDM wallbash template..."
    cp "$src_dcol" "$dst_dcol"
    print_ok "Template → $dst_dcol"

    if [ -f "$src_sh" ]; then
        cp "$src_sh" "$dst_sh"
        chmod +x "$dst_sh"
        print_ok "Script  → $dst_sh"
    fi

    # Install root helper + NOPASSWD sudo rule
    if [ ! -f "$SDDM_HELPER" ]; then
        print_msg "Installing root helper..."
        if sudo install -m 755 "$src_helper" "$SDDM_HELPER"; then
            print_ok "Helper  → $SDDM_HELPER"
        else
            print_err "Helper install failed — run with proper sudo access"
        fi
    else
        print_ok "Helper already installed at $SDDM_HELPER"
    fi

    if [ ! -f "$SDDM_SUDOERS" ]; then
        print_msg "Installing NOPASSWD sudo rule..."
        echo "${USER} ALL=(ALL) NOPASSWD: $SDDM_HELPER" | \
            sudo tee "$SDDM_SUDOERS" > /dev/null || {
            print_err "Sudoers install failed — run with proper sudo access"
            print_warn "  To install manually:"
            print_warn "    echo '${USER} ALL=(ALL) NOPASSWD: ${SDDM_HELPER}' | sudo tee ${SDDM_SUDOERS}"
            print_warn "    sudo chmod 440 ${SDDM_SUDOERS}"
        }
        sudo chmod 440 "$SDDM_SUDOERS" 2>/dev/null || true
        if [ -f "$SDDM_SUDOERS" ]; then
            print_ok "Sudoers → $SDDM_SUDOERS"
        fi
    else
        print_ok "NOPASSWD rule already exists at $SDDM_SUDOERS"
    fi

    # Apply current wallpaper colors immediately
    if [ -f "$CACHE_DIR/wallbash/sddm.conf" ] && [ -f "$CACHE_DIR/wall.set.png" ]; then
        print_msg "Applying current wallpaper colors to SDDM..."
        bash "$dst_sh" 2>/dev/null && print_ok "SDDM colors applied" || \
            print_skip "Could not apply SDDM colors (background mode)"
    elif [ -f "$CACHE_DIR/wall.set.png" ]; then
        print_msg "Generating initial SDDM colors..."
        if [ -f "$CACHE_DIR/wall.dcol" ]; then
            . "$CACHE_DIR/wall.dcol"
            cat > "$CACHE_DIR/wallbash/sddm.conf" << EOF
# Autogenerated colors by wallbash for SDDM
MainColor="#${dcol_txt1:-FFFFFF}"
AccentColor="#${dcol_1xa5:-6580A3}"
BackgroundColor="#${dcol_pry1:-132B4B}"
EOF
            bash "$dst_sh" 2>/dev/null && print_ok "SDDM initial colors applied" || \
                print_skip "Could not apply SDDM colors"
        else
            print_skip "No wallpaper cache yet — colors will apply on next wallpaper change"
        fi
    else
        print_skip "No wallpaper set yet — colors will apply on next wallpaper change"
    fi

    # Add startup hook so sddm runs on every Hyprland login
    if [ -f "$HYPR_USERPREFS" ]; then
        if ! grep -qs "$SDDM_EXEC_ONCE_LINE" "$HYPR_USERPREFS"; then
            print_msg "Adding SDDM startup hook to $HYPR_USERPREFS..."
            cat >> "$HYPR_USERPREFS" << EOF

# ${SDDM_EXEC_ONCE_LINE}
${SDDM_EXEC_ONCE_CMD}
EOF
            print_ok "SDDM will apply on every Hyprland login"
        else
            print_ok "SDDM startup hook already present"
        fi
    else
        print_warn "Hyprland userprefs.conf not found — cannot add startup hook"
        print_warn "  Add manually to your hyprland config:"
        print_warn "  ${SDDM_EXEC_ONCE_CMD}"
    fi
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
        print_ok "Kitty template installed"
    else
        print_err "  ❌ Kitty template missing"
        ok=1
    fi

    if [ -f "$HYDE_WALLBASH_DIR/darkreader.dcol" ]; then
        print_ok "Dark Reader template installed"
    else
        print_skip "Dark Reader template missing"
    fi

    if [ -f "$HYDE_WALLBASH_DIR/sddm.dcol" ]; then
        print_ok "SDDM template installed"
    else
        print_skip "SDDM template missing"
    fi

    if [ -f "$SDDM_HELPER" ]; then
        print_ok "SDDM root helper installed"
    else
        print_skip "SDDM root helper not installed"
    fi

    if [ -f "$SDDM_SUDOERS" ]; then
        print_ok "SDDM NOPASSWD sudo rule installed"
    else
        print_skip "SDDM NOPASSWD sudo rule not installed"
    fi

    if [ -f "$KITTY_CONF" ] && ! grep -q "current-theme.conf" "$KITTY_CONF" 2>/dev/null; then
        print_ok "Kitty config patched (no static theme override)"
    fi

    if [ -f "$FASTFETCH_CONF" ] && grep -q 'wall.sqre' "$FASTFETCH_CONF" 2>/dev/null; then
        print_ok "Fastfetch configured to show wallpaper"
    fi

    if [ -f "$HYDE_SCRIPTS_DIR/wallbash-check.sh" ]; then
        print_ok "Diagnostic script installed"
    else
        print_skip "Diagnostic script missing"
    fi

    if [ -f "$LIBS_DIR/node_modules/leveldown/package.json" ]; then
        print_ok "leveldown npm package installed"
    fi

    if [ "$ok" -eq 1 ]; then
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────
main() {
    echo "=============================================="
    echo "  Kitty + Dark Reader + SDDM + Fastfetch Wallbash"
    echo "  Auto-theme your terminal, browser, login screen"
    echo "=============================================="

    print_heading "Prerequisites"
    check_prerequisites
    snapshot_hyde_version

    print_heading "Kitty Terminal"
    install_kitty_template
    patch_kitty_conf

    print_heading "Dark Reader"
    install_darkreader_template

    print_heading "Terminal Logo (Fastfetch)"
    patch_fastfetch_logo

    print_heading "SDDM Login Screen"
    install_sddm

    print_heading "Applying"
    apply_kitty_theme

    # Apply Dark Reader if Brave is closed
    if command -v node &>/dev/null && [ -f "$HYDE_SCRIPTS_DIR/darkreader-apply.js" ]; then
        print_msg "Attempting Dark Reader apply..."
        node "$HYDE_SCRIPTS_DIR/darkreader-apply.js" 2>/dev/null && \
            print_msg "  Dark Reader colors applied" || \
            print_warn "  Dark Reader not applied (Brave may be running - close & retry)"
    fi

    verify

    echo ""
    print_msg "All done! Change your wallpaper to see everything update."
    print_msg "  • Kitty colors → auto (on wallpaper change)"
    print_msg "  • Terminal logo → always shows current wallpaper"
    print_msg "  • Dark Reader → auto-applies when Brave is closed"
    print_msg "  • SDDM login screen → matches your wallpaper colors"
    print_msg "  • Run wallbash-check.sh to verify the pipeline"
    echo ""
}

main
