#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for check in "$repo_root"/tests/check-*.sh; do
  printf 'running %s\n' "${check##*/}"
  sh "$check"
done

printf 'running shellcheck\n'
shellcheck "$repo_root"/tests/*.sh "$repo_root"/scripts/*.sh

printf 'checking shell syntax\n'
for file in "$repo_root"/home/.zshenv "$repo_root"/home/.zprofile \
  "$repo_root"/home/.zshrc "$repo_root"/config/zsh/*.zsh; do
  zsh -n "$file"
done
bash -n "$repo_root/home/.bashrc"
