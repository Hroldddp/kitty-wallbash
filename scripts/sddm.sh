#!/bin/bash

cacheDir="${cacheDir:-$HOME/.cache/hyde}"
COLORS_SRC="${cacheDir}/wallbash/sddm.conf"
WALLPAPER_SRC="${cacheDir}/wall.set.png"
SDDM_HELPER="/usr/local/bin/sddm-apply-wallbash"

[ -f "$COLORS_SRC" ] || { echo "[wallbash] sddm :: No cached colors at $COLORS_SRC"; exit 1; }
[ -f "$WALLPAPER_SRC" ] || { echo "[wallbash] sddm :: No wallpaper at $WALLPAPER_SRC"; exit 1; }
[ -x "$SDDM_HELPER" ] || { echo "[wallbash] sddm :: Helper not found at $SDDM_HELPER"; exit 1; }

# Copy colors and wallpaper to temp paths the root helper can read
TEMP_COLORS="/var/tmp/sddm-colors.conf"
TEMP_WALLPAPER="/var/tmp/sddm-bg.png"

cp "$COLORS_SRC" "$TEMP_COLORS"
cp "$WALLPAPER_SRC" "$TEMP_WALLPAPER"

# Apply via sudo -n (non-interactive).
# A NOPASSWD rule must be installed at /etc/sudoers.d/sddm-wallbash
# by install.sh. Using -n ensures NO password prompt, so pam_faillock
# is never triggered in background/headless execution.
sudo -n "$SDDM_HELPER" "$TEMP_COLORS" "$TEMP_WALLPAPER" 2>/dev/null || {
    echo "[wallbash] sddm :: sudo -n failed. Is the NOPASSWD rule installed?"
    echo "[wallbash] sddm :: Run install.sh to set it up, or add: "
    echo "[wallbash] sddm ::   ${USER} ALL=(ALL) NOPASSWD: ${SDDM_HELPER}"
    echo "[wallbash] sddm :: to /etc/sudoers.d/sddm-wallbash"
    rm -f "$TEMP_COLORS" "$TEMP_WALLPAPER"
    exit 1
}

rm -f "$TEMP_COLORS" "$TEMP_WALLPAPER"
