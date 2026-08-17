#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for check in "$repo_root"/tests/check-*.sh; do
  printf 'running %s\n' "${check##*/}"
  sh "$check"
done

printf 'running shellcheck\n'
shellcheck "$repo_root"/tests/*.sh

printf 'running statix\n'
statix check "$repo_root"

printf 'running deadnix\n'
deadnix --fail "$repo_root"
