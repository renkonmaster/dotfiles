#!/bin/sh
set -eu
repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
case ${1:-} in
  install|upgrade) ;;
  *) echo 'usage: tools.sh install|upgrade' >&2; exit 1 ;;
esac
# Use the tracked tool list even before it is linked into the home directory.
# Do not inherit tool declarations from the directory containing the checkout.
export MISE_GLOBAL_CONFIG_FILE="$repo_root/config/mise/config.toml"
MISE_CEILING_PATHS=$(dirname -- "$repo_root")
export MISE_CEILING_PATHS
cd "$repo_root"
exec mise "$1" --yes
