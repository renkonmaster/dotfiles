# WSL exposes Docker Desktop completion through a symlink that is broken while
# Docker Desktop is stopped. compinit reports the broken target on every fresh
# cache. A higher-priority no-op completion keeps the other distro completions.
__dotfiles_docker_completion=/usr/share/zsh/vendor-completions/_docker

if [[ -o interactive &&
      -L "$__dotfiles_docker_completion" &&
      ! -e "$__dotfiles_docker_completion" ]]; then
    __dotfiles_cache_dir="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh}"
    __dotfiles_completion_stubs="$__dotfiles_cache_dir/dotfiles-completions"

    if mkdir -p "$__dotfiles_completion_stubs" 2>/dev/null &&
       print -r -- '#compdef docker' \
           >"$__dotfiles_completion_stubs/_docker" 2>/dev/null; then
        fpath=("$__dotfiles_completion_stubs" $fpath)
    fi

    unset __dotfiles_cache_dir __dotfiles_completion_stubs
fi

unset __dotfiles_docker_completion
