#!/usr/bin/env bash
# check-docs-version.sh — the version the docs quote must be the version we ship.
#
#     bash scripts/check-docs-version.sh
#     bash scripts/check-docs-version.sh --self-check   # prove the gate can fail
#
# WHY. terminal-help prints one line on every shell, and that line carries
# VERSION. It is what a person reads back when they say what they are running,
# so the README quotes it — and a quoted string is a claim that rots silently.
# It rotted 21 versions wide (README said v0.14.0, VERSION said 0.35.0, #38),
# and every existing gate stayed green throughout, because none of them
# compares a document to the code.
#
# WHAT IT DOES NOT DO. It checks the BANNER form only — the string the tool
# actually prints. Prose that names an old version deliberately ("the v0.12.0
# regression", "as of v0.32.0") is history and must survive: a gate that forced
# those to the current version would destroy the only record of when a
# regression appeared.
#
# Fix a failure with `bash scripts/set-version.sh <x.y.z>`, which moves VERSION
# and the docs together.

set -uo pipefail
cd "$(dirname "$0")/.."

SELF_CHECK=0
[ "${1:-}" = "--self-check" ] && SELF_CHECK=1

note() { printf '  %s\n' "$*"; }

[ -f VERSION ] || { printf 'check-docs-version: no VERSION file — nothing to check against.\n' >&2; exit 1; }
want="$(tr -d '[:space:]' < VERSION)"
if [ -z "$want" ]; then
  printf 'check-docs-version: VERSION is empty. Every comparison would trivially pass.\n' >&2
  exit 1
fi

# Kept identical to set-version.sh's pattern, so the writer and the checker
# cannot disagree about what counts as a quoted version.
pattern='terminal-help v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}'

# The self-check plants the failure in a THROWAWAY COPY rather than in the
# working tree: a guard that dirties the repo to test itself is one nobody runs
# locally, and a `sed -i` that got interrupted would leave a false version
# committed by the very PR adding the guard.
root="."
if [ "$SELF_CHECK" -eq 1 ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp README.md "$tmp/README.md"
  sed -i.bak "s/$pattern/terminal-help v0.0.1/g" "$tmp/README.md"
  rm -f "$tmp/README.md.bak"
  root="$tmp"
  note "[self-check] planted a wrong version in a throwaway copy of README.md"
  echo
fi

echo "terminal-help — do the docs quote the version we ship?"
note "VERSION: $want"
echo

matches="$(grep -rno "$pattern" "$root" \
  --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=node_modules \
  --exclude-dir=.venv --exclude-dir=.venv-macos \
  --exclude=set-version.sh --exclude=check-docs-version.sh 2>/dev/null || true)"

total=0
stale=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  total=$((total + 1))
  got="${line##*terminal-help v}"
  where="${line%%:terminal-help*}"
  if [ "$got" = "$want" ]; then
    note "ok      $where"
  else
    note "STALE   $where — says v$got, VERSION says v$want"
    stale=$((stale + 1))
  fi
done <<LIST
$matches
LIST

echo
# A guard over an empty set is the failure this repo keeps writing rules about.
# Zero matches means the pattern stopped matching the docs — a rename, a moved
# README — not that everything is consistent.
if [ "$total" -eq 0 ]; then
  printf 'check-docs-version: 0 quoted version(s) found. The docs used to quote the\n' >&2
  printf '                    banner; if that moved, fix the pattern rather than\n' >&2
  printf '                    accepting a gate that inspects nothing.\n' >&2
  exit 1
fi

if [ "$SELF_CHECK" -eq 1 ]; then
  if [ "$stale" -gt 0 ]; then
    printf 'check-docs-version: %s of %s quoted version(s) flagged with the bug planted, which is correct.\n' "$stale" "$total"
    exit 0
  fi
  printf 'check-docs-version: the gate PASSED with a wrong version planted — IT PROVES NOTHING.\n' >&2
  exit 1
fi

if [ "$stale" -ne 0 ]; then
  printf 'check-docs-version: FAILED — %s of %s quoted version(s) are stale.\n' "$stale" "$total" >&2
  printf '                    Fix both at once: bash scripts/set-version.sh %s\n' "$want" >&2
  exit 1
fi

printf 'check-docs-version: OK — %s quoted version(s) checked, all say v%s.\n' "$total" "$want"
