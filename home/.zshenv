# Keep non-interactive startup small; interactive mise activation is in .zshrc.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/bin" "$HOME/.cargo/bin" $path)
export PATH

[[ ! -r "$HOME/.zshenv.local" ]] || source "$HOME/.zshenv.local"
