#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
profile_dir="$repo_root/vscode/Laptop-win"

test ! -e "$repo_root/.vscode/Laptop-win.code-profile" || {
  echo "monolithic VS Code profile still exists" >&2
  exit 1
}

for file in \
  "$profile_dir/settings.jsonc" \
  "$profile_dir/keybindings.jsonc" \
  "$profile_dir/snippets/latex.json" \
  "$profile_dir/snippets/typst.json"
do
  jq empty "$file"
done

test -s "$profile_dir/extensions.txt"
test "$(sort -u "$profile_dir/extensions.txt" | wc -l)" -eq \
     "$(wc -l < "$profile_dir/extensions.txt")"

sorted_extensions=$(mktemp)
trap 'rm -f "$sorted_extensions"' EXIT HUP INT TERM
sort "$profile_dir/extensions.txt" >"$sorted_extensions"
cmp -s "$profile_dir/extensions.txt" "$sorted_extensions" || {
  echo "extensions.txt must be sorted" >&2
  exit 1
}

if grep -ERq 'globalState|remote\.tunnels|mcpserver-' "$profile_dir"; then
  echo "volatile VS Code state remains" >&2
  exit 1
fi

if grep -Eq 'ms-vscode\.cpptools-extension-pack|vinirossa\.vscode-gitandgithub-pack|mathematic\.vscode-latex' "$profile_dir/extensions.txt"; then
  echo "redundant extension or extension pack remains" >&2
  exit 1
fi

if grep -Eq '"extensions\.autoUpdate"[[:space:]]*:[[:space:]]*false|"update\.mode"[[:space:]]*:[[:space:]]*"none"' "$profile_dir/settings.jsonc"; then
  echo "VS Code updates are still disabled without version pinning" >&2
  exit 1
fi
