#!/bin/sh
set -eu
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
mise_config="${MISE_GLOBAL_CONFIG_FILE:-${MISE_CONFIG_DIR:-$config_home/mise}/config.toml}"

if [ "${ZDOTDIR:-$HOME}" != "$HOME" ]; then
  echo 'This setup uses ~/.zshrc; unset ZDOTDIR before linking.' >&2
  exit 1
fi

link_file() {
  source_file="$repo_root/$1" target=$2
  [ "$source_file" != "$target" ] || return 0
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source_file" ]; then
    return
  fi
  # Preflight every backup path before changing any link.
  if [ -e "$target.pre-mise" ] || [ -L "$target.pre-mise" ]; then
    echo "backup already exists: $target.pre-mise" >&2
    exit 1
  fi
  [ "$phase" = apply ] || return 0
  mkdir -p "$(dirname -- "$target")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mv -- "$target" "$target.pre-mise"
  fi
  ln -s -- "$source_file" "$target"
  printf 'linked %s\n' "$target"
}

for phase in check apply; do
  link_file home/.zshenv "$HOME/.zshenv"
  link_file home/.zprofile "$HOME/.zprofile"
  link_file home/.zshrc "$HOME/.zshrc"
  link_file home/.aliases "$HOME/.aliases"
  link_file home/.gitconfig "$HOME/.gitconfig"
  link_file config/starship.toml "$config_home/starship.toml"
  link_file config/mise/config.toml "$mise_config"
done
