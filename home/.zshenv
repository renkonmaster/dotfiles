# Keep non-interactive startup small; interactive mise activation is in .zshrc.
typeset -U path PATH
path=("$HOME/.cargo/bin" "$HOME/.local/bin" "$HOME/bin" $path)
export PATH

[[ ! -r "$HOME/.zshenv.local" ]] || source "$HOME/.zshenv.local"
