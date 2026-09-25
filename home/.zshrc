# Interactive Zsh configuration. Local overrides belong in ~/.zshrc.local.
# Resolve the source file, including when ~/.zshrc is a symlink to this checkout.
typeset -g __dotfiles_root=${${(%):-%x}:A:h:h}
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin" $path)
export PATH

# Activate once in every new shell, even if MISE_SHELL was inherited.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

export ZSH="$HOME/.local/share/dotfiles/oh-my-zsh"
export ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump-$ZSH_VERSION"
mkdir -p "$ZSH_CACHE_DIR"
zstyle ':omz:update' mode disabled
ZSH_THEME=""
plugins=(git)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

source "$__dotfiles_root/config/zsh/pre-compinit.zsh"
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    autoload -Uz compinit
    compinit -d "$ZSH_COMPDUMP"
fi

HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=20000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
source "$__dotfiles_root/home/.aliases"

source "$__dotfiles_root/config/zsh/init.zsh"

[[ ! -r "$HOME/.zsh_aliases" ]] || source "$HOME/.zsh_aliases"
[[ ! -r "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"

# Load widget integrations after completion and local key bindings.
__dotfiles_plugins="$HOME/.local/share/dotfiles"
if [[ -r "$__dotfiles_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$__dotfiles_plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [[ -r "$__dotfiles_plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]]; then
    source "$__dotfiles_plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
fi
unset __dotfiles_plugins __dotfiles_root
