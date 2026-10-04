#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  CachyOS dotfiles UNINSTALLER
#   - undoes everything install.sh did EXCEPT packages/apps and fonts
#   - removes: bspwm config + dotfile symlinks, shortcuts, wallpaper/colors
#   - never touches: shutdown logo, ~/nixo/Downloads/downloadfile, ~/.fonts, packages
# ----------------------------------------------------------------------

set -uo pipefail

# ---------- Paths ----------
CONFIG_DIR="$HOME/.config"
DIR="$CONFIG_DIR/bspwm"

# ---------- Look & feel ----------
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
CYAN=$'\e[1;36m'
RESET=$'\e[0m'
TOTAL_STEPS=4
STEP=0

rule() { printf '═%.0s' $(seq 1 "$1"); }
info() { printf '%s  ➜ %s%s\n' "$CYAN" "$*" "$RESET"; }
ok()   { printf '%s  ✔ %s%s\n' "$GREEN" "$*" "$RESET"; }
warn() { printf '%s  ! %s%s\n' "$YELLOW" "$*" "$RESET"; }
die()  { printf '%s  ✘ %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

header() {
  clear
  printf '%s' "$CYAN"
  cat <<'EOF'
  ____          _            ___  ____
 / ___|__ _  ___| |__  _   _ / _ \/ ___|
| |   / _` |/ __| '_ \| | | | | | \___ \
| |__| (_| | (__| | | | |_| | |_| |___) |
 \____\__,_|\___|_| |_|\__, |\___/|____/
                       |___/
EOF
  printf '%s         D O T F I L E S   R E M O V E R%s\n' "$RED" "$RESET"
}

section() {
  STEP=$((STEP + 1))
  local title
  title=$(printf 'STEP %d/%d  %s' "$STEP" "$TOTAL_STEPS" "$1")
  printf '\n%s╔%s╗\n║ %-62s ║\n╚%s╝%s\n' "$CYAN" "$(rule 64)" "$title" "$(rule 64)" "$RESET"
}

finish() {
  printf '\n%s╔%s╗\n║ %-62s ║\n╚%s╝%s\n' "$GREEN" "$(rule 64)" \
    "ALL DONE - everything the installer set up is gone" "$(rule 64)" "$RESET"
}

# Removes the path only when it is a symlink, so real files are never lost.
unlink_if_link() {
  if [ -L "$1" ]; then
    rm -f -- "$1"
    ok "Unlinked $1"
  fi
}

# ---------- Step 1: checks ----------
preflight() {
  [ "$EUID" -ne 0 ] || die "Run this as your normal user, not root."
  sudo -v || die "sudo authentication failed."
  ok "All checks passed"
}

# ---------- Step 2: shortcuts ----------
remove_shortcuts() {
  local script entry
  for script in lf-archivemount autofocus autofocus_pad; do
    if [ -L "/usr/local/bin/$script" ]; then
      sudo rm -f "/usr/local/bin/$script"
      ok "Unlinked /usr/local/bin/$script"
    fi
  done
  for entry in "$HOME"/.local/share/applications/*; do
    if [ -L "$entry" ] && [[ $(readlink "$entry") == "$DIR"/* ]]; then
      unlink_if_link "$entry"
    fi
  done
}

# ---------- Step 3: dotfile links ----------
remove_dotfile_links() {
  local item
  for item in sxhkd eww lf dunst qt5ct gtk-3.0 betterlockscreenrc wpg; do
    unlink_if_link "$CONFIG_DIR/$item"
  done
  for item in .Xresources .xsettingsd Scripts; do
    unlink_if_link "$HOME/$item"
  done
  unlink_if_link "$DIR"
}

# ---------- Step 4: wallpaper & colors ----------
remove_wallpaper() {
  rm -rf "$HOME/.cache/wal"
  ok "Wallpaper colors and cache removed"
}

# ---------- Run ----------
main() {
  header
  section "Checking system";             preflight
  section "Removing app shortcuts";      remove_shortcuts
  section "Removing dotfile links";      remove_dotfile_links
  section "Removing wallpaper colors";   remove_wallpaper
  finish
}

main "$@"
