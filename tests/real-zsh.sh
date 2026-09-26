#!/bin/sh
# Run only in the isolated HOME prepared by integration.sh.
# shellcheck disable=SC2016
set -eu
cd "$HOME"

# Local overrides must be able to use already loaded plugins.
cat >"$HOME/.zshrc.local" <<'ZSH'
(( ${+functions[fast-theme]} && ${+functions[_zsh_autosuggest_start]} )) || exit 1
alias gemini=local-override
ZSH

for mode in -ic -lic; do
  /usr/bin/zsh -d "$mode" '
    [[ $HISTSIZE == 10000 && $SAVEHIST == 20000 ]] || exit 1
    [[ -o histfcntllock && -o sharehistory && -o histignorealldups ]] || exit 1
    [[ ! -o extendedhistory && ! -o histexpiredupsfirst ]] || exit 1
    [[ ! -o appendhistory && ! -o histfindnodups && ! -o histsavenodups ]] || exit 1
    [[ $aliases[gemini] == local-override && $aliases[ll] == eza* ]] || exit 1
    [[ $MISE_SHELL == zsh ]] || exit 1
    (( ${+functions[compdef]} && ${+functions[git_prompt_info]} )) || exit 1
    (( ${+functions[prompt_starship_precmd]} && ${+functions[__zoxide_z]} )) || exit 1
    [[ ${(j: :)ZSH_AUTOSUGGEST_STRATEGY} == "history completion" ]] || exit 1
    [[ $PATH != *"/nix/"* ]] || exit 1
    for tool in node go rustc cargo uv starship eza fzf zoxide direnv; do
      command -v "$tool" || exit 1
    done
    node --version && go version && rustc --version && cargo --version || exit 1
    print -r -- REAL_ZSH_OK
  ' 2>"$HOME/zsh.stderr"
  if [ -s "$HOME/zsh.stderr" ]; then
    cat "$HOME/zsh.stderr" >&2
    exit 1
  fi
done

/usr/bin/zsh -dc '[[ $path[1] == "$HOME/.cargo/bin" ]]'

# A child shell inherits MISE_SHELL; it must still initialize its own hooks.
/usr/bin/zsh -dic '/usr/bin/zsh -dic '\''
  (( ${+functions[prompt_starship_precmd]} && ${+functions[__zoxide_z]} )) || exit 1
  [[ $MISE_SHELL == zsh ]] || exit 1
'\'
