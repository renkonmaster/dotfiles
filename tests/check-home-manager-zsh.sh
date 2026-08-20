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
generated_zprofile="$generation/home-files/.zprofile"
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
test -s "$generated_zprofile" || {
  echo "Home Manager did not generate .zprofile" >&2
  exit 1
}
test -x "$managed_zsh" || {
  echo "Home Manager did not provide zsh" >&2
  exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

optional_hook="$test_root/optional-hook"
cat >"$optional_hook" <<'STUB'
#!/bin/sh
set -eu

name=${0##*/}
count_file="$DOTFILES_HOOK_COUNTS/$name"
count=0
test ! -f "$count_file" || count=$(cat "$count_file")
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"

case "$name" in
  fzf)
    test "$*" = '--zsh'
    printf '%s\n' 'typeset -gx DOTFILES_FZF_TEST=1'
    ;;
  zoxide)
    test "$*" = 'init zsh'
    printf '%s\n' \
      'function __zoxide_z() { :; }' \
      'typeset -gx DOTFILES_ZOXIDE_TEST=1'
    ;;
  starship)
    test "$*" = 'init zsh'
    printf '%s\n' \
      'typeset -gx STARSHIP_SHELL=zsh' \
      'typeset -gx DOTFILES_STARSHIP_TEST=1'
    ;;
  direnv)
    test "$*" = 'hook zsh'
    printf '%s\n' 'typeset -gx DOTFILES_DIRENV_TEST=1'
    ;;
  *)
    exit 1
    ;;
esac
STUB
chmod +x "$optional_hook"

startup_runner="$test_root/startup-runner"
cat >"$startup_runner" <<'RUNNER'
#!/bin/sh
set -eu

exec env -i \
  DOTFILES_HOOK_COUNTS="$DOTFILES_HOOK_COUNTS" \
  EXPECT_OPTIONAL_HOOKS="$EXPECT_OPTIONAL_HOOKS" \
  HOME="$ISOLATED_HOME" \
  LOGNAME=renkon \
  PATH=/usr/bin:/bin \
  SHELL="$SHELL_PATH" \
  STARSHIP_SHELL=zsh \
  TERM=xterm-256color \
  USER=renkon \
  ZDOTDIR="$ISOLATED_HOME/zdotdir" \
  "$SHELL_PATH" -lic '
    [[ $DOTFILES_ZSHRC_TEST_COMPLETE == 1 ]]
    [[ $MISE_SHELL == zsh ]]
    [[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == "history completion" ]]
    [[ "$(alias gemini)" == "gemini=agy" ]]
    [[ ":$PATH:" == *":$HOME/.cargo/bin:"* ]]

    if [[ $EXPECT_OPTIONAL_HOOKS == 1 ]]; then
      [[ $DOTFILES_FZF_TEST == 1 ]]
      [[ $DOTFILES_ZOXIDE_TEST == 1 ]]
      [[ $DOTFILES_STARSHIP_TEST == 1 ]]
      [[ $DOTFILES_DIRENV_TEST == 1 ]]
    fi

    print -r -- HM_ZSH_OK
  ' 2>"$STDERR_FILE"
RUNNER
chmod +x "$startup_runner"

prepare_home() {
  isolated_home=$1
  with_optional_hooks=$2
  zdotdir="$isolated_home/zdotdir"

  mkdir -p "$zdotdir"
  sed "s|/home/renkon|$isolated_home|g" \
    "$generated_zshenv" >"$zdotdir/.zshenv"
  sed "s|/home/renkon|$isolated_home|g" \
    "$generated_zprofile" >"$zdotdir/.zprofile"
  sed "s|/home/renkon|$isolated_home|g" \
    "$generated_zshrc" >"$zdotdir/.zshrc"
  printf '\ntypeset -g DOTFILES_ZSHRC_TEST_COMPLETE=1\n' >>"$zdotdir/.zshrc"

  if [ "$with_optional_hooks" -eq 1 ]; then
    mkdir -p "$isolated_home/.local/bin"
    for command in fzf zoxide starship direnv; do
      ln -s "$optional_hook" "$isolated_home/.local/bin/$command"
    done
  fi
}

run_startup() {
  shell_path=$1
  isolated_home=$2
  expect_optional_hooks=$3
  label=$4
  stderr_file="$test_root/$label.stderr"

  if ! output=$(
    DOTFILES_HOOK_COUNTS="$test_root/hook-counts" \
      EXPECT_OPTIONAL_HOOKS="$expect_optional_hooks" \
      ISOLATED_HOME="$isolated_home" \
      SHELL_PATH="$shell_path" \
      STDERR_FILE="$stderr_file" \
      script --quiet --return --command "$startup_runner" /dev/null
  ); then
    printf '%s startup failed\n' "$label" >&2
    cat "$stderr_file" >&2
    exit 1
  fi

  if [ -s "$stderr_file" ]; then
    printf '%s wrote unexpected stderr\n' "$label" >&2
    cat "$stderr_file" >&2
    exit 1
  fi

  printf '%s\n' "$output" | grep -Fq HM_ZSH_OK || {
    printf '%s did not complete startup\n' "$label" >&2
    exit 1
  }
}

mkdir -p "$test_root/hook-counts"

prepare_home "$test_root/managed-minimal" 0
run_startup "$managed_zsh" "$test_root/managed-minimal" 0 managed-minimal

system_zsh_runs=0
if [ -x /usr/bin/zsh ]; then
  prepare_home "$test_root/system-minimal" 0
  run_startup /usr/bin/zsh "$test_root/system-minimal" 0 system-minimal
  system_zsh_runs=1
else
  echo "system /usr/bin/zsh unavailable; skipping host-shell coverage"
fi

prepare_home "$test_root/managed-optional" 1
run_startup "$managed_zsh" "$test_root/managed-optional" 1 managed-optional

if [ "$system_zsh_runs" -eq 1 ]; then
  prepare_home "$test_root/system-optional" 1
  run_startup /usr/bin/zsh "$test_root/system-optional" 1 system-optional
fi

expected_hook_count=$((1 + system_zsh_runs))
for command in fzf zoxide starship direnv; do
  count=$(cat "$test_root/hook-counts/$command")
  test "$count" -eq "$expected_hook_count" || {
    echo "expected $command hook $expected_hook_count times, observed $count" >&2
    exit 1
  }
done
