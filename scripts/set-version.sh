#!/usr/bin/env bash
# set-version.sh — bump VERSION and every version the docs quote, together.
#
#     bash scripts/set-version.sh 0.37.0
#
# WHY THIS EXISTS. Two rules in this repo pull against each other: every PR
# bumps VERSION (CLAUDE.md), and the README quotes the banner that VERSION
# feeds. Bumping one without the other is not a typo, it is the DEFAULT
# outcome — measured over this repo's history, 32 commits touched VERSION and
# only 22 of them touched README. The gap that produced was 21 versions wide:
# the README advertised a version three-quarters stale while every test passed,
# because nothing compared the two.
#
# check-docs-version.sh is the gate that now refuses that state. This script is
# how you satisfy it in one command instead of hand-editing three code blocks
# and getting one of them wrong.
#
# It rewrites the BANNER form only — the string the tool actually prints. Prose
# elsewhere that names an old version on purpose ("the v0.12.0 regression") is
# history, not a stale claim, and is deliberately left alone.

set -uo pipefail
cd "$(dirname "$0")/.."

new="${1:-}"
if [ -z "$new" ]; then
  printf 'usage: bash scripts/set-version.sh <x.y.z>\n' >&2
  printf '       current: %s\n' "$(tr -d '[:space:]' < VERSION 2>/dev/null)" >&2
  exit 1
fi

if ! printf '%s' "$new" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  printf 'set-version: "%s" is not x.y.z\n' "$new" >&2
  exit 1
fi

[ -f VERSION ] || { printf 'set-version: no VERSION file here\n' >&2; exit 1; }
old="$(tr -d '[:space:]' < VERSION)"

if [ "$old" = "$new" ]; then
  printf 'set-version: VERSION is already %s — nothing to do\n' "$new" >&2
  exit 1
fi

printf '%s\n' "$new" > VERSION
printf '  VERSION  %s -> %s\n' "$old" "$new"

# The same pattern check-docs-version.sh scans for, so the two cannot disagree
# about what counts as a quoted version.
pattern='terminal-help v[0-9]\{1,\}\.[0-9]\{1,\}\.[0-9]\{1,\}'

rewrote=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  before="$(grep -c "$pattern" "$f" 2>/dev/null || true)"
  sed -i.bak "s/$pattern/terminal-help v$new/g" "$f"
  rm -f "$f.bak"
  printf '  docs     %s (%s occurrence(s))\n' "$f" "$before"
  rewrote=$((rewrote + 1))
done <<LIST
$(grep -rl "$pattern" . \
    --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=node_modules \
    --exclude-dir=.venv --exclude-dir=.venv-macos \
    --exclude=set-version.sh --exclude=check-docs-version.sh 2>/dev/null || true)
LIST

printf '\nset-version: OK — VERSION plus %s doc file(s) now say %s.\n' "$rewrote" "$new"
printf '             Verify with: bash scripts/check-docs-version.sh\n'
