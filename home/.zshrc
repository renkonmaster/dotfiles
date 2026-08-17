# ~/.zshrc: interactive Zsh configuration managed in dotfiles.
#
# Keep machine-specific settings and secrets in ~/.zshrc.local.

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable automatic update prompts for smooth startup
zstyle ':omz:update' mode disabled

ZSH_THEME=""

ZSH_AUTOSUGGEST_STRATEGY=(history completion)

plugins=(
	git
	zsh-autosuggestions
 	fast-syntax-highlighting
)

if [[ -r $ZSH/oh-my-zsh.sh ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# History ---------------------------------------------------------------------

HISTSIZE=10000
SAVEHIST=20000
HISTFILE="$HOME/.zsh_history"

setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

# PATH and tool bootstrap ------------------------------------------------------

__zshrc_path_prepend() {
    [[ -d $1 ]] || return 0

    case ":${PATH:-}:" in
        *:"$1":*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# mise and uv install into ~/.local/bin by default. rustup, `go install`, and
# pnpm keep their upstream user-level binary locations; runtime versions remain
# the responsibility of mise (Python is intentionally managed by uv).
__zshrc_path_prepend "$HOME/go/bin"
__zshrc_path_prepend "$HOME/.cargo/bin"

PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
if [[ -d $PNPM_HOME/bin ]]; then
    export PNPM_HOME
    __zshrc_path_prepend "$PNPM_HOME/bin"
fi

__zshrc_path_prepend "$HOME/bin"
__zshrc_path_prepend "$HOME/.local/bin"
export PATH

# Keep the existing standalone Google Cloud SDK installation portable.
__zshrc_gcloud_dir="$HOME/develop/mcp/google-cloud-sdk"
if [[ -r $__zshrc_gcloud_dir/path.zsh.inc ]]; then
    source "$__zshrc_gcloud_dir/path.zsh.inc"
fi

# Aliases ---------------------------------------------------------------------

if command -v dircolors >/dev/null 2>&1; then
    if [[ -r $HOME/.dircolors ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi

    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

if command -v clip.exe >/dev/null 2>&1; then
    alias clip='clip.exe'
elif command -v wl-copy >/dev/null 2>&1; then
    alias clip='wl-copy'
elif command -v xsel >/dev/null 2>&1; then
    alias clip='xsel --clipboard --input'
fi

if [[ -r $HOME/.aliases ]]; then
    source "$HOME/.aliases"
fi
if [[ -r $HOME/.zsh_aliases ]]; then
    source "$HOME/.zsh_aliases"
fi

# Completion and tool hooks ---------------------------------------------------

# Activate mise only for interactive shells.
if [[ ${MISE_SHELL:-} != zsh ]] && command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

# fzf integration
if command -v fzf >/dev/null 2>&1; then
    if __zshrc_fzf_init=$(fzf --zsh 2>/dev/null); then
        eval "$__zshrc_fzf_init"
    else
        if [[ -r /usr/share/doc/fzf/examples/completion.zsh ]]; then
            source /usr/share/doc/fzf/examples/completion.zsh
        fi
        if [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
            source /usr/share/doc/fzf/examples/key-bindings.zsh
        fi
    fi
    unset __zshrc_fzf_init
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi


if [[ -r $__zshrc_gcloud_dir/completion.zsh.inc ]]; then
    source "$__zshrc_gcloud_dir/completion.zsh.inc"
fi
unset __zshrc_gcloud_dir

# direnv asks to be initialized after other prompt hooks.
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

# Local overrides are deliberately untracked.
if [[ -r $HOME/.zshrc.local ]]; then
    source "$HOME/.zshrc.local"
fi

unset -f __zshrc_path_prepend
