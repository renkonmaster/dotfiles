#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
workflow="$repo_root/.github/workflows/check.yml"

uses_lines=$(grep -E '^[[:space:]]+- uses:' "$workflow")
test "$(printf '%s\n' "$uses_lines" | wc -l)" -eq 2

if printf '%s\n' "$uses_lines" |
  grep -Ev '@[0-9a-f]{40}[[:space:]]+#[[:space:]]+v[0-9]' >/dev/null
then
  echo "GitHub Actions must use full commit SHAs with version comments" >&2
  exit 1
fi

test -s "$repo_root/.github/dependabot.yml" || {
  echo "GitHub Actions pins have no automated update configuration" >&2
  exit 1
}
