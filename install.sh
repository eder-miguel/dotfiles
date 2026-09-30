#!/usr/bin/env bash
# Provision this machine from the repo:  git pull && ./install.sh
# Idempotent — re-run freely.
set -euo pipefail
shopt -s nullglob

KITTY_VERSION=0.49.1
STARSHIP_VERSION=1.26.0
RG_VERSION=15.2.0
FD_VERSION=10.2.0
BAT_VERSION=0.26.1
EZA_VERSION=0.23.5
FZF_VERSION=0.74.4
ZOXIDE_VERSION=0.10.0
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
    local have; have="$("$LOCAL/bin/kitty" --version 2>/dev/null | awk 'NR==1{print $2}')" || have=
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
    for src in "$REPO"/config/*; do
        src="${src%/}"
        local dst="$CONFIG/${src##*/}"
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then
            echo "ERROR: $dst exists and is not a symlink; move it aside" >&2
            exit 1
        fi
        ln -sfn "$src" "$dst"
        echo "linked $dst -> $src"
    done
}

install_zshenv() {
    local f="$HOME/.zshenv"
    local want='export ZDOTDIR="$HOME/code/dotfiles/zsh"
export SHELL=/usr/bin/zsh
typeset -U path
path=("$HOME/.local/bin" $path)
export skip_global_compinit=1'
    if [ -f "$f" ] && [ "$(cat "$f")" = "$want" ]; then
        echo "$f already up to date"; return
    fi
    if [ -e "$f" ]; then
        cp "$f" "$f.bak"
        echo "NOTE: backed up existing $f to $f.bak" >&2
    fi
    printf '%s\n' "$want" > "$f"
    echo "wrote $f"
}

install_starship() {
    local have; have="$("$LOCAL/bin/starship" --version 2>/dev/null | awk 'NR==1{print $2}')" || have=
    if [ "$have" = "$STARSHIP_VERSION" ]; then
        echo "starship $STARSHIP_VERSION already installed"
    else
        echo "installing starship $STARSHIP_VERSION (found: ${have:-none})"
        curl -sS https://starship.rs/install.sh \
            | sh -s -- -b "$LOCAL/bin" -y --version "v$STARSHIP_VERSION"
    fi
}

install_rg() {
    local have; have="$("$LOCAL/bin/rg" --version 2>/dev/null | awk 'NR==1{print $2}')" || have=""
    [[ "$have" == "$RG_VERSION" ]] && { echo "rg $RG_VERSION already installed"; return; }

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/rg.tar.gz" \
        "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VERSION/ripgrep-$RG_VERSION-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/rg.tar.gz" -C "$tmp"
    install -m755 "$tmp/ripgrep-$RG_VERSION-x86_64-unknown-linux-musl/rg" "$LOCAL/bin/rg"
    rm -rf "$tmp"
    echo "installed rg $RG_VERSION"
}

install_fd() {
    local have; have="$("$LOCAL/bin/fd" --version 2>/dev/null | awk 'NR==1{print $2}')" || have=""
    if [ "$have" = "$FD_VERSION" ]; then
        echo "fd $FD_VERSION already installed"; return
    fi
    echo "installing fd $FD_VERSION (found: ${have:-none})"

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/fd.tar.gz" \
        "https://github.com/sharkdp/fd/releases/download/v$FD_VERSION/fd-v$FD_VERSION-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/fd.tar.gz" -C "$tmp"
    install -m755 "$tmp/fd-v$FD_VERSION-x86_64-unknown-linux-musl/fd" "$LOCAL/bin/fd"
    rm -rf "$tmp"
    echo "installed fd $FD_VERSION"
}

install_bat() {
    local have; have="$("$LOCAL/bin/bat" --version 2>/dev/null | awk '{print $2}')" || have=""
    if [ "$have" = "$BAT_VERSION" ]; then
        echo "bat $BAT_VERSION already installed"; return
    fi
    echo "installing bat $BAT_VERSION (found: ${have:-none})"

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/bat.tar.gz" \
        "https://github.com/sharkdp/bat/releases/download/v$BAT_VERSION/bat-v$BAT_VERSION-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/bat.tar.gz" -C "$tmp"
    install -m755 "$tmp/bat-v$BAT_VERSION-x86_64-unknown-linux-musl/bat" "$LOCAL/bin/bat"
    rm -rf "$tmp"
    echo "installed bat $BAT_VERSION"
}

install_eza() {
    local have; have="$("$LOCAL/bin/eza" --version 2>/dev/null | awk 'NR==2{print $1}')" || have=""
    have="${have#v}"
    if [ "$have" = "$EZA_VERSION" ]; then
        echo "eza $EZA_VERSION already installed"; return
    fi
    echo "installing eza $EZA_VERSION (found: ${have:-none})"

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/eza.tar.gz" \
        "https://github.com/eza-community/eza/releases/download/v$EZA_VERSION/eza_x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/eza.tar.gz" -C "$tmp"
    install -m755 "$tmp/eza" "$LOCAL/bin/eza"
    rm -rf "$tmp"
    echo "installed eza $EZA_VERSION"
}

install_fzf() {
    local have; have="$("$LOCAL/bin/fzf" --version 2>/dev/null | awk '{print $1}')" || have=""
    if [ "$have" = "$FZF_VERSION" ]; then
        echo "fzf $FZF_VERSION already installed"; return
    fi
    echo "installing fzf $FZF_VERSION (found: ${have:-none})"

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/fzf.tar.gz" \
        "https://github.com/junegunn/fzf/releases/download/v$FZF_VERSION/fzf-$FZF_VERSION-linux_amd64.tar.gz"
    tar -xzf "$tmp/fzf.tar.gz" -C "$tmp"
    install -m755 "$tmp/fzf" "$LOCAL/bin/fzf"
    rm -rf "$tmp"
    echo "installed fzf $FZF_VERSION"
}

install_zoxide() {
    local have; have="$("$LOCAL/bin/zoxide" --version 2>/dev/null | awk '{print $2}')" || have=""
    have="${have#v}"
    if [ "$have" = "$ZOXIDE_VERSION" ]; then
        echo "zoxide $ZOXIDE_VERSION already installed"; return
    fi
    echo "installing zoxide $ZOXIDE_VERSION (found: ${have:-none})"

    local tmp; tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/zoxide.tar.gz" \
        "https://github.com/ajeetdsouza/zoxide/releases/download/v$ZOXIDE_VERSION/zoxide-$ZOXIDE_VERSION-x86_64-unknown-linux-musl.tar.gz"
    tar -xzf "$tmp/zoxide.tar.gz" -C "$tmp"
    install -m755 "$tmp/zoxide" "$LOCAL/bin/zoxide"
    rm -rf "$tmp"
    echo "installed zoxide $ZOXIDE_VERSION"
}

install_kitty
install_starship
install_desktop_entry
install_font
link_configs
install_zshenv
install_rg
install_fd
install_bat
install_eza
install_fzf
install_zoxide

case ":$PATH:" in
    *":$LOCAL/bin:"*) ;;
    *) echo "NOTE: $LOCAL/bin not on PATH in this shell; the desktop entry needs it at session level" >&2 ;;
esac
