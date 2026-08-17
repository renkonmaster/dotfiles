#!/bin/sh
# shellcheck disable=SC2016 # Single-quoted programs are evaluated by Zsh.
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

generation=$(
  nix build --no-link --print-out-paths \
    .#homeConfigurations.renkon.activationPackage
)

generated_zshenv="$generation/home-files/.zshenv"
generated_zshrc="$generation/home-files/.zshrc"
managed_zsh="$generation/home-path/bin/zsh"

test -s "$generated_zshenv" || {
  echo "Home Manager did not generate .zshenv" >&2
  exit 1
}
test -s "$generated_zshrc" || {
  echo "Home Manager did not generate .zshrc" >&2
  exit 1
}
test -x "$managed_zsh" || {
  echo "Home Manager did not provide zsh" >&2
  exit 1
}

test_home=$(mktemp -d)
trap 'rm -rf "$test_home"' EXIT HUP INT TERM

if ! output=$(
  env -i \
    HOME="$test_home" \
    PATH=/usr/bin:/bin \
    TERM=dumb \
    "$managed_zsh" -dfc '
      source "$1"
      ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
      source "$2"
      [[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == "history completion" ]]
      [[ "$(alias gemini)" == "gemini=agy" ]]
      print -r -- HM_ZSH_OK
    ' zsh "$generated_zshenv" "$generated_zshrc" 2>&1
); then
  printf '%s\n' "$output" >&2
  exit 1
fi

printf '%s\n' "$output" | grep -Fq HM_ZSH_OK

if printf '%s\n' "$output" | grep -Eq 'command not found|no such file or directory'; then
  printf '%s\n' "$output" >&2
  exit 1
fi
