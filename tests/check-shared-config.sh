#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
gitconfig="$repo_root/home/.gitconfig"
starship_config="$repo_root/config/starship.toml"

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT HUP INT TERM

git config --file "$gitconfig" --list >/dev/null

excludes_file=$(
  HOME="$test_home" git config --file "$gitconfig" --path --get core.excludesfile
)
test "$excludes_file" = "$test_home/.config/git/ignore" || {
  echo "core.excludesfile did not resolve relative to HOME" >&2
  exit 1
}

include_file=$(
  HOME="$test_home" git config --file "$gitconfig" --path --get include.path
)
test "$include_file" = "$test_home/.gitconfig.local" || {
  echo "local Git include did not resolve relative to HOME" >&2
  exit 1
}

STARSHIP_CONFIG="$starship_config" starship print-config >/dev/null
