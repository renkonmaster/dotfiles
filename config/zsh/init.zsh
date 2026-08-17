# Custom integrations appended to the Home Manager-generated ~/.zshrc.

setopt HIST_REDUCE_BLANKS

typeset -U path PATH

[[ -d "$HOME/go/bin" ]] && path=("$HOME/go/bin" $path)
[[ -d "$HOME/.cargo/bin" ]] && path=("$HOME/.cargo/bin" $path)

export PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
[[ -d "$PNPM_HOME/bin" ]] && path=("$PNPM_HOME/bin" $path)

[[ -d "$HOME/bin" ]] && path=("$HOME/bin" $path)
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
export PATH

if command -v dircolors >/dev/null 2>&1; then
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

if command -v clip.exe >/dev/null 2>&1; then
    alias clip='clip.exe'
elif command -v wl-copy >/dev/null 2>&1; then
    alias clip='wl-copy'
elif command -v xsel >/dev/null 2>&1; then
    alias clip='xsel --clipboard --input'
fi

if command -v fzf >/dev/null 2>&1; then
    if __dotfiles_fzf_init=$(fzf --zsh 2>/dev/null); then
        eval "$__dotfiles_fzf_init"
    else
        [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] &&
            source /usr/share/doc/fzf/examples/completion.zsh
        [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] &&
            source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
    unset __dotfiles_fzf_init
fi

if command -v zoxide >/dev/null 2>&1 &&
    (( ! ${+functions[__zoxide_z]} )); then
    eval "$(zoxide init zsh)"
fi

if [[ -z ${STARSHIP_SHELL:-} ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

__dotfiles_gcloud_dir="$HOME/develop/mcp/google-cloud-sdk"
if [[ -r "$__dotfiles_gcloud_dir/path.zsh.inc" ]]; then
    source "$__dotfiles_gcloud_dir/path.zsh.inc"
fi
if [[ -r "$__dotfiles_gcloud_dir/completion.zsh.inc" ]]; then
    source "$__dotfiles_gcloud_dir/completion.zsh.inc"
fi
unset __dotfiles_gcloud_dir

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if [[ -r "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
