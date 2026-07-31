# ~/.bashrc: interactive Bash configuration managed in dotfiles.
#
# Keep machine-specific settings and secrets in ~/.bashrc.local.

# Nothing below is needed by non-interactive shells.
case $- in
    *i*) ;;
    *) return ;;
esac

# History ---------------------------------------------------------------------

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000

shopt -s histappend
shopt -s checkwinsize

# Share new history between concurrently running shells while preserving the
# previous command's exit status for prompt hooks.
__bashrc_history_sync() {
    local exit_status=$?
    builtin history -a
    builtin history -n
    return "$exit_status"
}

declare -a PROMPT_COMMAND
if [[ " ${PROMPT_COMMAND[*]-} " != *" __bashrc_history_sync "* ]]; then
    PROMPT_COMMAND+=(__bashrc_history_sync)
fi

# PATH and tool bootstrap ------------------------------------------------------

__bashrc_path_prepend() {
    [[ -d $1 ]] || return 0

    case ":${PATH:-}:" in
        *:"$1":*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# mise and uv install into ~/.local/bin by default. rustup, `go install`, and
# pnpm keep their upstream user-level binary locations; runtime versions remain
# the responsibility of mise (Python is intentionally managed by uv).
__bashrc_path_prepend "$HOME/go/bin"
__bashrc_path_prepend "$HOME/.cargo/bin"

PNPM_HOME="${PNPM_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/pnpm}"
if [[ -d $PNPM_HOME/bin ]]; then
    export PNPM_HOME
    __bashrc_path_prepend "$PNPM_HOME/bin"
fi

__bashrc_path_prepend "$HOME/bin"
__bashrc_path_prepend "$HOME/.local/bin"
export PATH

# Keep the existing standalone Google Cloud SDK installation portable.
__bashrc_gcloud_dir="$HOME/develop/mcp/google-cloud-sdk"
if [[ -r $__bashrc_gcloud_dir/path.bash.inc ]]; then
    source "$__bashrc_gcloud_dir/path.bash.inc"
    unset script_link apparent_sdk_dir sdk_dir bin_path
fi

# Shell behavior and prompt ----------------------------------------------------

if [[ -z ${debian_chroot:-} && -r /etc/debian_chroot ]]; then
    debian_chroot=$(< /etc/debian_chroot)
fi

if [[ ${TERM:-dumb} != dumb ]] &&
    command -v tput >/dev/null 2>&1 &&
    tput setaf 1 >/dev/null 2>&1; then
    PS1='${debian_chroot:+($debian_chroot)}\[\e[01;32m\]\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

case ${TERM:-} in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac

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
if [[ -r $HOME/.bash_aliases ]]; then
    source "$HOME/.bash_aliases"
fi

# Completion and tool hooks ---------------------------------------------------

if ! shopt -oq posix; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi

# Activate mise only for interactive shells. Scripts and CI should use
# `mise exec`/`mise run`, or add mise shims from their login-shell setup.
if [[ ${MISE_SHELL:-} != bash ]] && command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# uv and uvx require no activation hook; ~/.local/bin above is sufficient.

# fzf 0.48+ provides its own integration. Fall back to Debian's packaged
# scripts for the older version currently installed in this environment.
if command -v fzf >/dev/null 2>&1; then
    if __bashrc_fzf_init=$(fzf --bash 2>/dev/null); then
        eval "$__bashrc_fzf_init"
    else
        if [[ -r /usr/share/doc/fzf/examples/completion.bash ]]; then
            source /usr/share/doc/fzf/examples/completion.bash
        fi
        if [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
            source /usr/share/doc/fzf/examples/key-bindings.bash
        fi
    fi
    unset __bashrc_fzf_init
fi

if ! declare -F __zoxide_hook >/dev/null &&
    command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [[ -r $__bashrc_gcloud_dir/completion.bash.inc ]]; then
    source "$__bashrc_gcloud_dir/completion.bash.inc"
fi
unset __bashrc_gcloud_dir

# direnv asks to be initialized after other prompt hooks.
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi

# Local overrides are deliberately untracked.
if [[ -r $HOME/.bashrc.local ]]; then
    source "$HOME/.bashrc.local"
fi

unset -f __bashrc_path_prepend
