#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

for file in \
  flake.lock \
  modules/dotfiles.nix \
  modules/git.nix \
  modules/zsh.nix
do
  test -s "$file" || {
    echo "missing required file: $file" >&2
    exit 1
  }
done

nix-instantiate --parse flake.nix >/dev/null
nix-instantiate --parse home.nix >/dev/null
nix-instantiate --parse modules/dotfiles.nix >/dev/null
nix-instantiate --parse modules/git.nix >/dev/null
nix-instantiate --parse modules/zsh.nix >/dev/null

nix flake metadata --no-write-lock-file >/dev/null
