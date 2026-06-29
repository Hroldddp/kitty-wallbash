#!/usr/bin/env bash
# wallbash-check.sh — diagnose the kitty-wallbash pipeline
# Run: bash wallbash-check.sh
set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyde"
HYDE_WALLBASH_ALWAYS="$CONFIG_DIR/hyde/wallbash/always"
HYDE_SCRIPTS_DIR="$CONFIG_DIR/hyde/wallbash/scripts"
HYDE_LIB="$HOME/.local/lib/hyde"
KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"
FASTFETCH_CONF="$CONFIG_DIR/fastfetch/config.jsonc"
COLORS_FILE="$CACHE_DIR/wallbash/darkreader.json"
WALL_DCOL="$CACHE_DIR/wall.dcol"
WALL_SQRE="$CACHE_DIR/wall.sqre"
HYDE_VERSION_FILE="$HOME/.local/state/hyde/version"
SNAPSHOT_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-wallbash/hyde-version.txt"
LIBS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kitty-wallbash"

PASS=0; FAIL=0; WARN=0

pass() { PASS=$((PASS+1)); printf "  \033[1;32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "  \033[1;31m✗\033[0m %s\n" "$1"; }
warn() { WARN=$((WARN+1)); printf "  \033[1;33m⚠\033[0m %s\n" "$1"; }

echo "============================================"
echo "  Kitty-Wallbash Diagnostic Check"
echo "============================================"
echo ""

# ── 1. HyDE version ────────────────────────────
echo "--- HyDE ---"
if [ -f "$HYDE_VERSION_FILE" ]; then
  source "$HYDE_VERSION_FILE"
  echo "  Version: ${HYDE_VERSION:-unknown}"
  echo "  Branch:  ${HYDE_BRANCH:-unknown}"
  echo "  Commit:  ${HYDE_COMMIT_HASH:-unknown}"
  if [ -f "$SNAPSHOT_FILE" ]; then
    echo "  Installed against: $(cat "$SNAPSHOT_FILE")"
  fi
  pass "HyDE version found"
else
  warn "HyDE version file not found"
fi

# ── 2. Wallbash engine ─────────────────────────
echo ""
echo "--- Wallbash Engine ---"
COLOR_SET="$HYDE_LIB/color.set.sh"
if [ -f "$COLOR_SET" ]; then
  if grep -q 'always.*\.dcol' "$COLOR_SET" 2>/dev/null; then
    pass "always/ templates are processed (color.set.sh)"
  else
    fail "always/ template processing not found in color.set.sh"
  fi
else
  fail "color.set.sh not found at $COLOR_SET"
fi

# Check wallbash variable convention matches our templates
if [ -f "$WALL_DCOL" ]; then
  if grep -q 'dcol_pry1=' "$WALL_DCOL" 2>/dev/null; then
    pass "Wallbash variable naming convention (dcol_pry1) matches templates"
  else
    fail "Wallbash variable naming does not match expected pattern"
  fi
else
  fail "No wall.dcol found (run wallbash first)"
fi

# ── 3. Templates ──────────────────────────────
echo ""
echo "--- Templates ---"
for t in kitty.dcol darkreader.dcol sddm.dcol; do
  if [ -f "$HYDE_WALLBASH_ALWAYS/$t" ]; then
    pass "Template installed: $t"
  else
    fail "Template missing: $t"
  fi
done

# Validate template placeholders
for t in kitty.dcol darkreader.dcol sddm.dcol; do
  f="$HYDE_WALLBASH_ALWAYS/$t"
  if [ -f "$f" ]; then
    header=$(head -1 "$f")
    if echo "$header" | grep -q '|'; then
      pass "$t has valid header (target|command)"
    else
      fail "$t header missing pipe delimiter"
    fi
    # Check it uses valid wallbash variables (strip _rgb/_rgba suffix before validating)
    bad=$(grep -oP '<wallbash_\w+' "$f" 2>/dev/null \
          | sed 's/_rgb\|_rgba([^)]*)//g' \
          | sort -u \
          | grep -vP '^(<wallbash_pry[1-4]|<wallbash_txt[1-4]|<wallbash_[1-4]xa[1-9]|<wallbash_mode)$' || true)
    if [ -n "$bad" ]; then
      warn "Unknown wallbash variables in $t: $(echo "$bad" | tr '\n' ' ')"
    else
      pass "$t uses valid wallbash variables"
    fi
  fi
done

# ── 4. Scripts ─────────────────────────────────
echo ""
echo "--- Scripts ---"
for s in darkreader.sh darkreader-apply.js; do
  if [ -f "$HYDE_SCRIPTS_DIR/$s" ]; then
    pass "Script installed: $s"
  else
    warn "Script missing: $s"
  fi
done

if [ -d "$LIBS_DIR/node_modules/leveldown" ]; then
  pass "leveldown npm package installed"
else
  warn "leveldown not installed — Dark Reader auto-apply unavailable"
fi

# ── 5. Dark Reader LevelDB ────────────────────
echo ""
echo "--- Dark Reader LevelDB ---"
if command -v node &>/dev/null && [ -f "$HYDE_SCRIPTS_DIR/darkreader-apply.js" ]; then
  DR_OUTPUT=$(node "$HYDE_SCRIPTS_DIR/darkreader-apply.js" --check 2>/dev/null) || true
  DR_EXIT=$?
  case $DR_EXIT in
    0)
      pass "Dark Reader LevelDB: healthy"
      echo "$DR_OUTPUT" | grep '^  ' || true
      ;;
    2) warn "leveldown not installed" ;;
    3) warn "LevelDB locked (Brave running) — close Brave and retry" ;;
    *) fail "Dark Reader LevelDB check failed (exit $DR_EXIT)" ;;
  esac
else
  warn "Cannot check LevelDB (node or script missing)"
fi

# ── 6. Dark Reader JSON ───────────────────────
echo ""
echo "--- Dark Reader Colors ---"
if [ -f "$COLORS_FILE" ]; then
  pass "Wallpaper colors file exists"
  dark_bg=$(jq -r '.darkreader.colors.darkSchemeBackgroundColor' "$COLORS_FILE" 2>/dev/null || echo "")
  dark_fg=$(jq -r '.darkreader.colors.darkSchemeTextColor' "$COLORS_FILE" 2>/dev/null || echo "")
  if [ -n "$dark_bg" ] && [ -n "$dark_fg" ]; then
    echo "  Dark BG: $dark_bg  Dark FG: $dark_fg"
    pass "Colors file has valid entries"
  else
    fail "Colors file missing expected fields"
  fi
else
  fail "No colors file at $COLORS_FILE — change wallpaper to generate"
fi

# ── 7. SDDM theme ────────────────────────────
echo ""
echo "--- SDDM Login Screen ---"
SDDM_THEME_CONF="/usr/share/sddm/themes/Candy/theme.conf"
if [ -f "$SDDM_THEME_CONF" ]; then
  main_color=$(grep -oP '^MainColor="\K[^"]+' "$SDDM_THEME_CONF" 2>/dev/null)
  accent_color=$(grep -oP '^AccentColor="\K[^"]+' "$SDDM_THEME_CONF" 2>/dev/null)
  bg_color=$(grep -oP '^BackgroundColor="\K[^"]+' "$SDDM_THEME_CONF" 2>/dev/null)
  if [ -n "$main_color" ] && [ -n "$accent_color" ] && [ -n "$bg_color" ]; then
    pass "SDDM Candy theme has valid colors"
    echo "  Main: $main_color  Accent: $accent_color  BG: $bg_color"
  else
    fail "SDDM theme.conf missing expected color keys"
  fi
  SDDM_BG="/usr/share/sddm/themes/Candy/backgrounds/wallpaper.png"
  if [ -f "$SDDM_BG" ]; then
    pass "SDDM wallpaper exists"
  else
    warn "SDDM wallpaper missing"
  fi
else
  warn "SDDM Candy theme not found at $SDDM_THEME_CONF"
fi

if [ -x "/usr/local/bin/sddm-apply-wallbash" ]; then
  pass "SDDM root helper installed"
else
  warn "SDDM root helper not installed"
fi

# ── 8. Kitty config ───────────────────────────
echo ""
echo "--- Kitty ---"
if [ -f "$KITTY_CONF" ]; then
  if grep -q "current-theme.conf" "$KITTY_CONF" 2>/dev/null; then
    fail "Kitty config still has static theme include"
  else
    pass "Kitty config has no static theme override"
  fi
  if grep -q "include hyde.conf" "$KITTY_CONF" 2>/dev/null; then
    pass "Kitty config includes hyde.conf"
  else
    warn "Kitty config missing hyde.conf include"
  fi
else
  fail "Kitty config not found"
fi

THEME_CONF="$CONFIG_DIR/kitty/theme.conf"
if [ -f "$THEME_CONF" ]; then
  if grep -q 'background' "$THEME_CONF" 2>/dev/null; then
    pass "Kitty theme.conf exists with colors"
  fi
else
  warn "Kitty theme.conf not generated yet (change wallpaper)"
fi

# ── 9. SDDM systemd watcher ────────────────────
echo ""
echo "--- SDDM Systemd Watcher ---"
if systemctl --user is-enabled sddm-watch.path &>/dev/null; then
  pass "SDDM path watcher enabled"
else
  warn "SDDM path watcher not enabled (re-run install.sh)"
fi
if systemctl --user is-active sddm-watch.path &>/dev/null; then
  pass "SDDM path watcher active"
else
  warn "SDDM path watcher not active (re-run install.sh or start manually)"
fi

# ── 10. Fastfetch logo ─────────────────────────
echo ""
echo "--- Fastfetch Logo ---"
if [ -f "$FASTFETCH_CONF" ]; then
  if grep -q 'wall.sqre' "$FASTFETCH_CONF" 2>/dev/null; then
    pass "Fastfetch configured to show wallpaper logo"
  else
    warn "Fastfetch not configured for wallpaper logo"
  fi
else
  warn "Fastfetch config not found"
fi
if [ -e "$WALL_SQRE" ]; then
  pass "Wallpaper thumbnail exists at wall.sqre"
else
  warn "Wallpaper thumbnail missing — run wallbash or change wallpaper"
fi

# ── Summary ──────────────────────────────────
echo ""
echo "============================================"
printf "  \033[1;32m%d passed\033[0m, \033[1;31m%d failed\033[0m, \033[1;33m%d warnings\033[0m\n" "$PASS" "$FAIL" "$WARN"
echo "============================================"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
