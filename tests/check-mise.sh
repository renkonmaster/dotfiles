#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

generation=$(
  nix build --no-link --print-out-paths \
    .#homeConfigurations.renkon.activationPackage
)

mise_config="$generation/home-files/.config/mise/config.toml"
generated_zshrc="$generation/home-files/.zshrc"
managed_mise="$generation/home-path/bin/mise"
activation="$generation/activate"

test -s "$mise_config" || {
  echo "Home Manager did not generate the global mise configuration" >&2
  exit 1
}

test -x "$managed_mise" || {
  echo "Home Manager did not provide mise" >&2
  exit 1
}

for tool in direnv fzf go rust starship uv zoxide; do
  grep -Fqx "$tool = \"latest\"" "$mise_config" || {
    echo "mise configuration omits $tool@latest" >&2
    exit 1
  }
done

grep -Fqx 'node = "lts"' "$mise_config" || {
  echo "mise configuration omits node@lts" >&2
  exit 1
}

test "$(grep -c ' = ' "$mise_config")" -eq 8 || {
  echo "mise configuration contains an unexpected tool set" >&2
  exit 1
}

grep -Fq '/bin/mise install --yes' "$activation" || {
  echo "Home Manager activation does not install configured mise tools" >&2
  exit 1
}

test "$(grep -Fc 'activate zsh' "$generated_zshrc")" -eq 1 || {
  echo "generated Zsh configuration must activate mise exactly once" >&2
  exit 1
}
