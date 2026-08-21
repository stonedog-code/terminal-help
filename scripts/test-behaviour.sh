#!/usr/bin/env bash
# test-behaviour.sh — the pytest tier: drive a real zsh, read what it printed.
#
#   bash scripts/test-behaviour.sh            # run it
#   bash scripts/test-behaviour.sh --self-check   # must FAIL — proves it can
#
# Nothing here tests Python. pytest is the harness, not the subject: it is here
# because this tier is a MATRIX — twelve topics times five flag combinations
# times a line-count assertion each — and a matrix written as linear bash is a
# thousand lines nobody reads. scripts/test-user-file-loads.sh stays; it answers
# a different question (does a real ~/.zshrc load a real ~/.zshrc-user.sh) and
# is already proved non-vacuous.
#
# A MISSING TOOL IS A FAILURE, NOT A SKIP — the same rule as check-syntax.sh.
# No uv, or no zsh, means this tier examined nothing, and a run that reports
# success over an empty set is the failure this repo keeps finding.

set -uo pipefail
cd "$(dirname "$0")/.."

# Per-platform environment directory. This repo is reachable over SMB from a
# Mac and a Linux box at once, and a .venv holds one machine's compiled
# extensions and absolute-path shebangs. See scripts/uv-env.sh.
. "$(dirname "$0")/uv-env.sh"

if ! command -v uv > /dev/null 2>&1; then
  printf 'test-behaviour: uv is not installed, so NOTHING was tested.\n' >&2
  printf '                Install it: curl -LsSf https://astral.sh/uv/install.sh | sh\n' >&2
  exit 1
fi
if ! command -v zsh > /dev/null 2>&1; then
  printf 'test-behaviour: zsh is not installed, so NOTHING was tested.\n' >&2
  printf '                Install it (apt-get install zsh / brew install zsh).\n' >&2
  exit 1
fi

uv sync --quiet --group dev || { printf 'test-behaviour: uv sync failed.\n' >&2; exit 1; }

if [ "${1:-}" = "--self-check" ]; then
  # Plant a real defect in a COPY of the tree and require the suite to catch it.
  # The tree under test is a copy precisely so a self-check can never leave the
  # working tree modified — the failure mode of every in-place plant.
  tmp=$(mktemp -d) || exit 1
  trap 'rm -rf "$tmp"' EXIT
  cp -R . "$tmp/repo" 2>/dev/null
  rm -rf "$tmp/repo/.git" "$tmp/repo/.venv" "$tmp/repo/.venv-macos"
  # The defect: the _info twin stops being generated. Several named tests must
  # go red, and test_info_twin_matches_help by name.
  sed -i.bak '/th_info_twin "get_${name}_help"/d' "$tmp/repo/lib/topics.zsh"
  out=$(cd "$tmp/repo" && uv run --quiet pytest 2>&1)
  rc=$?
  printf '%s\n' "$out" | tail -20
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'test_info_twin_matches_help'; then
    printf '\n  [self-check] the suite FAILED on the planted defect, by name. Correct.\n'
    exit 0
  fi
  printf '\n  [self-check] the suite passed with the twin generator removed — IT PROVES NOTHING.\n' >&2
  exit 1
fi

uv run --quiet pytest "$@"
