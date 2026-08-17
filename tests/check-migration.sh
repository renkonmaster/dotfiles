#!/bin/sh
# shellcheck disable=SC2016 # These are literal snippets required in the runbook.
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
runbook="$repo_root/docs/home-manager-migration.md"

generation=$(
  cd "$repo_root"
  nix build --no-link --print-out-paths \
    .#homeConfigurations.renkon.activationPackage
)

find -L "$generation/home-files" -type f -printf '%P\n' |
  while IFS= read -r managed_file; do
    grep -Fqx "  $managed_file" "$runbook" || {
      echo "migration inventory omits $managed_file" >&2
      exit 1
    }
  done

grep -Fq '[[ -e "$backup" || -L "$backup" ]]' "$runbook" || {
  echo "backup collision check does not detect symlinks" >&2
  exit 1
}

grep -Fq 'mv -- "$current" "$backup"' "$runbook" || {
  echo "runbook does not move foreign links before activation" >&2
  exit 1
}

if grep -Eq '(^|[[:space:]])rm([[:space:]]|$)' "$runbook"; then
  echo "runbook must not contain automatic rm commands" >&2
  exit 1
fi
