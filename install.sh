#!/usr/bin/env bash
# ----------------------------------------------------------------------
#  CachyOS dotfiles installer
#   - removes : BetterDiscord, zsh, AstroNvim, Spicetify, qutebrowser,
#               st, network-dmenu (and anything named like it)
#   - links   : dotfiles from ~/nixo/Downloads/downloadfile
#   - installs: Zen Browser, Steam
#   - sets    : shutdown logo from ~/cachyos-logo.png
# ----------------------------------------------------------------------

set -uo pipefail

# ---------- Paths ----------
CONFIG_DIR="$HOME/.config"
DIR="$CONFIG_DIR/bspwm"
DOTFILES="$HOME/nixo/Downloads/downloadfile"
LOGO_SRC="$HOME/cachyos-logo.png"
LOGO_DEST="$HOME/Downloads/CachyOS.png"
PLYMOUTH_THEMES="/usr/share/plymouth/themes"

# ---------- Look & feel ----------
RED=$'\e[1;31m'
GREEN=$'\e[1;32m'
YELLOW=$'\e[1;33m'
CYAN=$'\e[1;36m'
RESET=$'\e[0m'
TOTAL_STEPS=8
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
  printf '%s      D O T F I L E S   I N S T A L L E R%s\n' "$RED" "$RESET"
}

section() {
  STEP=$((STEP + 1))
  local title
  title=$(printf 'STEP %d/%d  %s' "$STEP" "$TOTAL_STEPS" "$1")
  printf '\n%s╔%s╗\n║ %-62s ║\n╚%s╝%s\n' "$CYAN" "$(rule 64)" "$title" "$(rule 64)" "$RESET"
}

finish() {
  printf '\n%s╔%s╗\n║ %-62s ║\n╚%s╝%s\n' "$GREEN" "$(rule 64)" \
    "ALL DONE - log out and back in to apply everything" "$(rule 64)" "$RESET"
}

# ---------- Package helpers ----------
is_installed() { pacman -Qq "$1" &>/dev/null; }

# Removes every given package that is installed, in one transaction.
remove_pkgs() {
  local found=() pkg
  for pkg in "$@"; do
    if is_installed "$pkg"; then found+=("$pkg"); fi
  done
  if [ "${#found[@]}" -eq 0 ]; then return 0; fi
  if sudo pacman -Rns --noconfirm "${found[@]}"; then
    ok "Removed packages: ${found[*]}"
  else
    warn "Could not remove: ${found[*]}"
  fi
}

# ---------- Step 1: checks ----------
preflight() {
  [ "$EUID" -ne 0 ] || die "Run this as your normal user, not root."
  local cmd
  for cmd in sudo pacman yay; do
    command -v "$cmd" &>/dev/null || die "Missing required command: $cmd"
  done
  [ -d "$DOTFILES" ] || die "Dotfiles folder not found: $DOTFILES"
  if [ -d "$DOTFILES/files" ]; then DOTFILES="$DOTFILES/files"; fi
  info "Dotfiles source: $DOTFILES"
  sudo -v || die "sudo authentication failed."
  ok "All checks passed"
}

# ---------- Step 2: removals ----------
remove_betterdiscord() {
  info "Removing BetterDiscord"
  if command -v betterdiscordctl &>/dev/null; then
    betterdiscordctl uninstall || warn "betterdiscordctl could not uninstall BetterDiscord"
  fi
  remove_pkgs betterdiscordctl betterdiscordctl-git
  rm -rf "$CONFIG_DIR/BetterDiscord" "$HOME/.local/share/betterdiscordctl"
}

remove_zsh() {
  info "Removing zsh"
  local login_shell new_shell
  login_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
  if [[ $login_shell == */zsh ]]; then
    new_shell=$(command -v fish || command -v bash)
    info "Login shell is zsh, switching to $new_shell first"
    if ! chsh -s "$new_shell"; then
      warn "Could not change the login shell, skipping zsh removal"
      return 0
    fi
  fi
  remove_pkgs cachyos-zsh-config zsh
  rm -rf "$HOME/.zshenv" "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zsh_history" \
    "$HOME"/.zcompdump* "$CONFIG_DIR/zsh"
}

remove_astronvim() {
  info "Removing AstroNvim"
  rm -rf "$CONFIG_DIR/nvim" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"
}

remove_spicetify() {
  info "Removing Spicetify"
  if command -v spicetify &>/dev/null; then
    spicetify restore || warn "spicetify restore failed (Spotify may stay patched until reinstalled)"
  fi
  remove_pkgs spicetify-cli spicetify-cli-git
  sudo rm -f /usr/local/bin/spicetifyreload
  rm -rf "$CONFIG_DIR/spicetify" "$HOME/.cache/spicetify"
}

remove_qutebrowser() {
  info "Removing qutebrowser"
  remove_pkgs qutebrowser qutebrowser-git
  rm -rf "$CONFIG_DIR/qutebrowser" "$HOME/.local/share/qutebrowser" "$HOME/.cache/qutebrowser"
}

remove_st() {
  info "Removing st terminal"
  remove_pkgs st
  sudo rm -f /usr/local/bin/st /usr/local/bin/st_pad /usr/local/share/man/man1/st.1
}

remove_network_dmenu() {
  info "Removing network-dmenu and everything named like it"
  local pkgs=()
  mapfile -t pkgs < <(pacman -Qq | grep -iE 'network(manager)?-dmenu')
  remove_pkgs "${pkgs[@]}"
  sudo find /usr/local -iname '*network*dmenu*' -prune -exec rm -rf {} + 2>/dev/null
  find "$CONFIG_DIR" "$HOME/.local" "$HOME/.cache" -iname '*network*dmenu*' -prune -exec rm -rf {} + 2>/dev/null
}

remove_old_apps() {
  remove_betterdiscord
  remove_zsh
  remove_astronvim
  remove_spicetify
  remove_qutebrowser
  remove_st
  remove_network_dmenu
}

# ---------- Step 3: dotfiles ----------
link_dotfiles() {
  rm -rf "$DIR" "$CONFIG_DIR/wpg" "$CONFIG_DIR/sxhkd" "$CONFIG_DIR/lf" "$CONFIG_DIR/qt5ct" \
    "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/dunst" "$HOME/.Xresources" "$HOME/.xsettingsd"
  ln -sfn "$DOTFILES" "$DIR"
  ln -sfn "$DIR/wpg" "$CONFIG_DIR/wpg"
  if [ -f /usr/bin/wpg-install.sh ]; then
    bash /usr/bin/wpg-install.sh -g
  else
    warn "wpg-install.sh not found, skipping GTK theme setup"
  fi

  local item
  for item in sxhkd eww lf dunst qt5ct gtk-3.0 betterlockscreenrc; do
    ln -sfn "$DIR/$item" "$CONFIG_DIR/$item"
  done
  for item in .Xresources .xsettingsd Scripts; do
    ln -sfn "$DIR/$item" "$HOME/$item"
  done
  ok "Dotfiles linked"
}

# ---------- Step 4: fonts ----------
install_fonts() {
  mkdir -p "$HOME/.fonts"
  cp -r "$DOTFILES"/fonts/. "$HOME/.fonts/"
  fc-cache -r
  ok "Fonts copied"
}

# ---------- Step 5: shortcuts ----------
link_shortcuts() {
  local script
  for script in lf-archivemount autofocus autofocus_pad; do
    sudo ln -sf "$DIR/Scripts/$script" /usr/local/bin/
  done
  mkdir -p "$HOME/.local/share/applications"
  ln -sf "$DIR"/applications/* "$HOME/.local/share/applications/"
  ok "Shortcuts created"
}

# ---------- Step 6: new apps ----------
install_apps() {
  info "Installing Zen Browser"
  if yay -S --needed --noconfirm zen-browser-bin; then
    ok "Zen Browser installed"
  else
    warn "Zen Browser install failed"
  fi

  info "Installing Steam (pick your GPU's lib32 Vulkan driver if asked)"
  if sudo pacman -S --needed steam; then
    ok "Steam installed"
  else
    warn "Steam install failed (is [multilib] enabled in /etc/pacman.conf?)"
  fi
}

# ---------- Step 7: shutdown logo ----------
# Only the copy on the root filesystem is changed. The initramfs is NOT
# rebuilt, so the boot splash keeps its old logo and only shutdown changes.
set_shutdown_logo() {
  [ -f "$LOGO_SRC" ] || { warn "$LOGO_SRC not found, skipping"; return 0; }

  local theme theme_dir
  theme=$(grep -hm1 '^Theme=' /etc/plymouth/plymouthd.conf /usr/share/plymouth/plymouthd.defaults 2>/dev/null | head -n1)
  theme=${theme#Theme=}
  theme_dir="$PLYMOUTH_THEMES/$theme"

  if [ -z "$theme" ] || [ ! -f "$theme_dir/watermark.png" ]; then
    warn "Active Plymouth theme has no watermark.png, skipping"
    return 0
  fi

  info "Plymouth theme: $theme"
  if [ ! -f "$theme_dir/watermark.png.bak" ]; then
    sudo cp "$theme_dir/watermark.png" "$theme_dir/watermark.png.bak"
  fi
  if sudo install -m 644 "$LOGO_SRC" "$theme_dir/watermark.png"; then
    mkdir -p "$HOME/Downloads"
    mv -f "$LOGO_SRC" "$LOGO_DEST"
    ok "Shutdown logo set, image moved to $LOGO_DEST"
  else
    warn "Could not set the shutdown logo"
  fi
}

# ---------- Step 8: wallpaper ----------
set_wallpaper() {
  wpg -s 63.jpg && ok "Wallpaper and theme applied" || warn "wpg could not set 63.jpg"
}

# ---------- Run ----------
main() {
  header
  section "Checking system";            preflight
  section "Removing old apps";          remove_old_apps
  section "Linking dotfiles";           link_dotfiles
  section "Copying fonts";              install_fonts
  section "Creating app shortcuts";     link_shortcuts
  section "Installing Zen and Steam";   install_apps
  section "Setting shutdown logo";      set_shutdown_logo
  section "Setting wallpaper";          set_wallpaper
  finish
}

main "$@"
