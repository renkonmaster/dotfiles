#!/bin/sh
# shellcheck disable=SC2016 # The single-quoted program is evaluated by Zsh.
set -eu

# ZLE integrations need a terminal, including in CI.
if [ ! -t 0 ]; then
  export DOTFILES_ZSH_TEST="$0"
  exec script -qec 'sh "$DOTFILES_ZSH_TEST"' /dev/null
fi

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
zsh_bin=$(command -v zsh)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

mkdir -p "$test_root/minimal" "$test_root/full/.local/bin" "$test_root/counts"
for profile in minimal full; do
  for file in .zshenv .zprofile .zshrc; do
    ln -s "$repo_root/home/$file" "$test_root/$profile/$file"
  done
done

# No plugins or user-installed commands: completion and history still work.
env -i HOME="$test_root/minimal" PATH=/usr/bin:/bin TERM=dumb \
  "$zsh_bin" -dlic '
    [[ $HISTSIZE == 10000 && $SAVEHIST == 20000 ]] || exit 1
    [[ -o sharehistory && -o histignorealldups && -o histignorespace ]] || exit 1
    (( ${+functions[compdef]} )) || exit 1
    [[ $aliases[gemini] == agy ]] || exit 1
    [[ -o histfcntllock && ! -o extendedhistory && ! -o histexpiredupsfirst ]] || exit 1
  '

cat >"$test_root/hook" <<'STUB'
#!/bin/sh
set -eu
name=${0##*/}
printf '%s\n' "$*" >>"$DOTFILES_COUNTS/$name"
case "$name:$*" in
  'mise:activate zsh') printf '%s\n' 'typeset -gx MISE_SHELL=zsh' ;;
  'fzf:--zsh') printf '%s\n' 'typeset -g DOTFILES_FZF=1' ;;
  'zoxide:init zsh') printf '%s\n' 'typeset -g DOTFILES_ZOXIDE=1' ;;
  'starship:init zsh') printf '%s\n' 'typeset -g DOTFILES_STARSHIP=1' ;;
  'direnv:hook zsh') printf '%s\n' 'typeset -g DOTFILES_DIRENV=1' ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$test_root/hook"
for tool in mise fzf zoxide starship direnv eza; do
  ln -s "$test_root/hook" "$test_root/full/.local/bin/$tool"
done

plugins="$test_root/full/.local/share/dotfiles"
mkdir -p "$plugins/oh-my-zsh" "$plugins/zsh-autosuggestions" \
  "$plugins/fast-syntax-highlighting"
cat >"$plugins/oh-my-zsh/oh-my-zsh.sh" <<'STUB'
[[ $MISE_SHELL == zsh && $plugins == git && -z $ZSH_THEME ]] || exit 1
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"
typeset -g DOTFILES_OMZ=1
STUB
cat >"$test_root/full/.zshrc.local" <<'STUB'
[[ $DOTFILES_FZF == 1 && $DOTFILES_DIRENV == 1 ]] || exit 1
[[ $DOTFILES_AUTOSUGGEST == 1 && $DOTFILES_HIGHLIGHT == 1 ]] || exit 1
alias gemini=local-override
typeset -g DOTFILES_LOCAL=1
STUB
cat >"$plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" <<'STUB'
[[ "${(j: :)ZSH_AUTOSUGGEST_STRATEGY}" == 'history completion' ]] || exit 1
typeset -g DOTFILES_AUTOSUGGEST=1
STUB
cat >"$plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" <<'STUB'
[[ $DOTFILES_AUTOSUGGEST == 1 ]] || exit 1
typeset -g DOTFILES_HIGHLIGHT=1
STUB

# Inherited MISE_SHELL must not suppress activation in a new Zsh process.
env -i HOME="$test_root/full" PATH=/usr/bin:/bin TERM=dumb \
  MISE_SHELL=zsh DOTFILES_COUNTS="$test_root/counts" \
  "$zsh_bin" -dlic '
    [[ $DOTFILES_OMZ == 1 && $DOTFILES_HIGHLIGHT == 1 ]] || exit 1
    [[ $DOTFILES_FZF == 1 && $DOTFILES_ZOXIDE == 1 ]] || exit 1
    [[ $DOTFILES_STARSHIP == 1 && $DOTFILES_DIRENV == 1 ]] || exit 1
    [[ $aliases[gemini] == local-override ]] || exit 1
    [[ $aliases[ll] == eza* ]] || exit 1
  '

for tool in mise fzf zoxide starship direnv; do
  test "$(wc -l <"$test_root/counts/$tool")" -eq 1 || {
    echo "expected one $tool hook per shell" >&2
    exit 1
  }
done
