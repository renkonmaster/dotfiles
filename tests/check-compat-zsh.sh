#!/bin/sh
# shellcheck disable=SC2016 # Single-quoted programs are evaluated by Zsh.
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
zshrc="$repo_root/home/.zshrc"
zsh_bin=$(command -v zsh)

"$zsh_bin" -n "$zshrc"

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

if ! output=$(
  env -i \
    HOME="$test_root/home-without-mise" \
    PATH=/usr/bin:/bin \
    TERM=dumb \
    "$zsh_bin" -dfc '
      source "$1"
      [[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == "history completion" ]]
    ' "$zsh_bin" "$zshrc" 2>&1
); then
  printf '%s\n' "$output" >&2
  echo "compatibility zsh failed without optional user tools" >&2
  exit 1
fi

mkdir -p "$test_root/bin" "$test_root/home-with-mise"
printf '0\n' >"$test_root/mise-count"

cat >"$test_root/bin/mise" <<'STUB'
#!/bin/sh
set -eu

test "$#" -eq 2
test "$1" = activate
test "$2" = zsh

count=$(cat "$MISE_COUNT_FILE")
count=$((count + 1))
printf '%s\n' "$count" >"$MISE_COUNT_FILE"
printf 'typeset -gx MISE_SHELL=zsh\n'
STUB
chmod +x "$test_root/bin/mise"

env -i \
  HOME="$test_root/home-with-mise" \
  MISE_COUNT_FILE="$test_root/mise-count" \
  PATH="$test_root/bin:/usr/bin:/bin" \
  TERM=dumb \
  "$zsh_bin" -dfc 'source "$1"' "$zsh_bin" "$zshrc"

mise_count=$(cat "$test_root/mise-count")
if [ "$mise_count" -ne 1 ]; then
  echo "expected mise activation once, observed $mise_count calls" >&2
  exit 1
fi
