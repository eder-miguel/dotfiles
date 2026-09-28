#!/usr/bin/env bash
# Provision this machine from the repo:  git pull && ./install.sh
# Idempotent — re-run freely.
set -euo pipefail
shopt -s nullglob

KITTY_VERSION=0.49.1
NF_RELEASE=3.5.1
NF_ASSET=JetBrainsMono                     # release asset / zip name
NF_GLOB='JetBrainsMonoNerdFontMono-*.ttf'  # Mono variant only, inside the zip
NF_FAMILY='JetBrainsMono Nerd Font Mono'   # name fontconfig reports for it

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL="$HOME/.local"
CONFIG="$HOME/.config"
FONTS="$LOCAL/share/fonts"
APPS="$LOCAL/share/applications"

install_kitty() {
    local have="$(kitty --version 2>/dev/null | awk '{print $2}')" || have=
    if [ "$have" = "$KITTY_VERSION" ]; then
        echo "kitty $KITTY_VERSION already installed"
    else
        echo "installing kitty $KITTY_VERSION (found: ${have:-none})"
        curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh \
            | sh /dev/stdin launch=n "installer=version-$KITTY_VERSION"
    fi
    mkdir -p "$LOCAL/bin"
    ln -sf "$LOCAL/kitty.app/bin/kitty" "$LOCAL/kitty.app/bin/kitten" "$LOCAL/bin/"
}

install_desktop_entry() {
    mkdir -p "$APPS"
    sed -e "s|^Exec=kitty|Exec=$LOCAL/kitty.app/bin/kitty|" \
        -e "s|^TryExec=kitty|TryExec=$LOCAL/kitty.app/bin/kitty|" \
        -e "s|^Icon=kitty|Icon=$LOCAL/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|" \
        "$LOCAL/kitty.app/share/applications/kitty.desktop" > "$APPS/kitty.desktop"
    echo kitty.desktop > "$CONFIG/xdg-terminals.list"   # read by 25.04+, inert on 22.04
}

install_font() {
    local fams; fams="$(fc-list : family)"
    if grep -qF "$NF_FAMILY" <<<"$fams"; then
        echo "$NF_FAMILY already installed"
        return
    fi
    echo "installing $NF_FAMILY (nerd-fonts $NF_RELEASE)"
    mkdir -p "$FONTS"
    local tmp; tmp="$(mktemp -d)"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NF_RELEASE/$NF_ASSET.zip" -o "$tmp/font.zip"
    unzip -oq "$tmp/font.zip" "$NF_GLOB" -d "$FONTS"
    rm -rf "$tmp"
    fc-cache -f "$FONTS"
}

link_configs() {
    for src in "$REPO"/*/; do
        src="${src%/}"
        local dst="$CONFIG/${src##*/}"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "ERROR: $dst exists and is not a symlink; move it into $src first" >&2
            exit 1
        fi
        ln -sfn "$src" "$dst"
        echo "linked $dst -> $src"
    done
}

install_kitty
install_desktop_entry
install_font
link_configs

case ":$PATH:" in
    *":$LOCAL/bin:"*) ;;
    *) echo "NOTE: $LOCAL/bin not on PATH in this shell; the desktop entry needs it at session level" >&2 ;;
esac
