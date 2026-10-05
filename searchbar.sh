#!/usr/bin/env bash
set -euo pipefail

sudo pacman -S --needed wofi papirus-icon-theme ttf-jetbrains-mono-nerd

GTK_INI="$HOME/.config/gtk-3.0/settings.ini"
mkdir -p "$HOME/.config/gtk-3.0"

if [ -f "$GTK_INI" ]; then
    if grep -q '^gtk-icon-theme-name' "$GTK_INI"; then
        sed -i 's/^gtk-icon-theme-name.*/gtk-icon-theme-name=Papirus-Dark/' "$GTK_INI"
    elif grep -q '^\[Settings\]' "$GTK_INI"; then
        sed -i '/^\[Settings\]/a gtk-icon-theme-name=Papirus-Dark' "$GTK_INI"
    else
        printf '[Settings]\ngtk-icon-theme-name=Papirus-Dark\n' >> "$GTK_INI"
    fi
else
    printf '[Settings]\ngtk-icon-theme-name=Papirus-Dark\ngtk-application-prefer-dark-theme=1\n' > "$GTK_INI"
fi

REPO="$HOME/Hyprland-Simple-Setup"
if [ -d "$REPO/.git" ]; then
    git -C "$REPO" pull --ff-only
else
    git clone --depth=1 https://github.com/Firstp1ck/Hyprland-Simple-Setup "$REPO"
fi

mkdir -p "$HOME/.config/wofi"
cp "$REPO/dotfiles/.config/wofi/config" "$REPO/dotfiles/.config/wofi/menu.css" "$HOME/.config/wofi/"

wofi --show drun --style "$HOME/.config/wofi/menu.css"
