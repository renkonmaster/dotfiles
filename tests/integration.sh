#!/bin/sh
# shellcheck disable=SC2016 # The child shell expands these expressions.
set -eu
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
mise_bin=$(readlink -f "$(command -v mise)")
case "$mise_bin" in
  /nix/*) echo 'Use a standalone mise binary for integration testing.' >&2; exit 1 ;;
esac
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/.local/bin"
cp "$mise_bin" "$test_root/.local/bin/mise"

# Test installation and real plugins without inheriting Nix or user config.
env -i HOME="$test_root" PATH="$test_root/.local/bin:/usr/bin:/bin" \
  MISE_CONFIG_DIR="$test_root/.config/mise" \
  MISE_DATA_DIR="$test_root/.local/share/mise" \
  MISE_CACHE_DIR="$test_root/.cache/mise" \
  MISE_STATE_DIR="$test_root/.local/state/mise" \
  MISE_CEILING_PATHS="$(dirname -- "$repo_root")" \
  MISE_TRUSTED_CONFIG_PATHS="$repo_root" MISE_YES=1 TERM=xterm-256color \
  sh -eu -c '
    cd "$1"
    mise run setup
    MISE_OFFLINE=1 mise run setup
    script -qec "sh tests/real-zsh.sh" /dev/null
  ' sh "$repo_root"
