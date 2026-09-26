#!/bin/sh
set -eu
plugin_root="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles"
mkdir -p "$plugin_root"

install_plugin() {
  name=$1 url=$2 ref=$3
  target="$plugin_root/$name"
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    git init -q "$target"
    git -C "$target" remote add origin "$url"
  fi
  # Never overwrite a foreign repository or local edits.
  [ "$(git -C "$target" remote get-url origin)" = "$url" ] || {
    echo "unexpected plugin origin: $target" >&2; exit 1
  }
  [ -z "$(git -C "$target" status --porcelain)" ] || {
    echo "plugin has local edits: $target" >&2; exit 1
  }
  # Remember the fetched pin locally, so repeated setup needs no network.
  revision=$(git -C "$target" rev-parse --verify "refs/dotfiles/$ref^{commit}" 2>/dev/null) || revision=
  if [ -n "$revision" ] && [ "$(git -C "$target" rev-parse HEAD)" = "$revision" ]; then
    return
  fi
  git -C "$target" fetch --depth=1 origin "$ref:refs/dotfiles/$ref"
  git -C "$target" checkout --detach "refs/dotfiles/$ref"
}

# Edit these three pins to update plugins. Match the former environment.
install_plugin oh-my-zsh https://github.com/ohmyzsh/ohmyzsh.git 97b27bb2ec0701330b18c2d3e340b22e742b3fa8
install_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git v0.7.1
install_plugin fast-syntax-highlighting https://github.com/zdharma-continuum/fast-syntax-highlighting.git v1.56
