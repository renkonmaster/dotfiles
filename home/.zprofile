# Login shells (including non-interactive ones) can use mise-managed tools.
typeset -U path PATH
path=("${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims" $path)
export PATH

[[ ! -r "$HOME/.zprofile.local" ]] || source "$HOME/.zprofile.local"
