#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

patterns='gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY'

if rg -n --hidden --glob '!.git/**' --glob '!graphify-out/**' \
  --pcre2 "$patterns" "$repo_root" >/dev/null
then
  echo "possible credential material found" >&2
  exit 1
fi
