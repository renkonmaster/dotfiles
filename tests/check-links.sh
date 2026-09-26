#!/bin/sh
set -eu
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mkdir -p "$test_root/home" "$test_root/config/mise"
printf 'original\n' >"$test_root/home/.zshrc"
ln -s /missing/old-config "$test_root/home/.gitconfig"
printf 'keep\n' >"$test_root/home/.zshrc.local"
# A late collision must prevent changes to earlier files, including dangling links.
ln -s /missing/backup "$test_root/config/mise/config.toml.pre-mise"
link_files() {
  env -i HOME="$test_root/home" XDG_CONFIG_HOME="$test_root/config" \
    PATH=/usr/bin:/bin sh "$repo_root/scripts/link.sh"
}
if link_files >"$test_root/output" 2>&1; then
  echo 'expected backup collision to stop linking' >&2; exit 1
fi
test ! -e "$test_root/home/.zshenv"
test "$(cat "$test_root/home/.zshrc")" = original
rm "$test_root/config/mise/config.toml.pre-mise"
link_files
link_files
test "$(cat "$test_root/home/.zshrc.pre-mise")" = original
test "$(readlink "$test_root/home/.gitconfig.pre-mise")" = /missing/old-config
test "$(readlink "$test_root/config/mise/config.toml")" = "$repo_root/config/mise/config.toml"
test "$(readlink "$test_root/home/.zshrc")" = "$repo_root/home/.zshrc"
test "$(cat "$test_root/home/.zshrc.local")" = keep
