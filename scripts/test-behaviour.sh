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

# Plant one real defect in a COPY of the tree and require a NAMED test to catch
# it. The tree under test is a copy precisely so a self-check can never leave
# the working tree modified — the failure mode of every in-place plant.
#
#   plant <label> <sed-expression> <test-name-that-must-appear>
plant() {
  label=$1 expr=$2 want=$3
  tmp=$(mktemp -d) || return 1
  cp -R . "$tmp/repo" 2>/dev/null
  rm -rf "$tmp/repo/.git" "$tmp/repo/.venv" "$tmp/repo/.venv-macos"
  sed -i.bak "$expr" "$tmp/repo/lib/topics.zsh"
  out=$(cd "$tmp/repo" && uv run --quiet pytest 2>&1)
  rc=$?
  rm -rf "$tmp"
  # No pipes here, and that is load-bearing. `printf | grep -q` looks
  # harmless, but grep -q exits the moment it matches, which closes the pipe
  # and hands printf an EPIPE — and with `set -o pipefail` (line 18) the
  # PIPELINE then reports failure even though the match succeeded. So a
  # correctly-caught plant gets reported as "IT PROVES NOTHING", and whether
  # it does depends on how much output the suite produced: the race only
  # became reachable once the suite grew past ~200 tests. `tail -8` had the
  # same EPIPE, which is where the stray "printf: write error: Broken pipe"
  # in the CI log came from.
  printf '%s\n' "$(printf '%s\n' "$out" | tail -8)"
  case "$out" in *"$want"*) matched=1 ;; *) matched=0 ;; esac
  if [ "$rc" -ne 0 ] && [ "$matched" -eq 1 ]; then
    printf '  [self-check] %s: FAILED on the plant, and %s went red. Correct.\n\n' "$label" "$want"
    return 0
  fi
  # Say WHICH of the two ways this went wrong. The single old message fired
  # for both, and the two need opposite responses: a suite that stayed green
  # means the guard does not catch the defect, while a suite that went red
  # without naming the expected test means the plant landed but something
  # else caught it — or the detection itself is broken, which is what the
  # EPIPE race above did.
  if [ "$rc" -eq 0 ]; then
    printf '  [self-check] %s: the suite PASSED with the defect planted — IT PROVES NOTHING.\n' "$label" >&2
  else
    printf '  [self-check] %s: the suite failed (rc=%s) but %s was not among the failures.\n' "$label" "$rc" "$want" >&2
  fi
  return 1
}

if [ "${1:-}" = "--self-check" ]; then
  # TWO plants, because this tier answers two different questions and a guard
  # is only proved by the failure it was written for.
  #
  # The second exists because of NEH-1091. A stray `print` at load time — six
  # junk lines in every new shell — passed ALL FOUR checks on main (measured
  # 2026-08-22: exit 0, 37 assertions, 165 tests). The `name=value` guard in
  # test-user-file-loads.sh knows the shape of the ONE defect it already caught;
  # it does not generalise. So this plant is deliberately a DIFFERENT shape from
  # that one, and the test that must catch it asserts the whole of what a new
  # shell printed rather than looking for noise.
  fails=0
  plant "twin generator removed" \
        '/th_info_twin "get_${name}_help"/d' \
        'test_info_twin_matches_help' || fails=$((fails + 1))
  plant "stray output at load time" \
        's#\[\[ -n $fn \]\] || continue#[[ -n $fn ]] || continue\n        print -r -- "loading sub-section $fn"#' \
        'test_a_quiet_shell_prints_absolutely_nothing' || fails=$((fails + 1))
  if [ "$fails" -eq 0 ]; then
    printf '  [self-check] 2 of 2 plants were caught by name. Correct.\n'
    exit 0
  fi
  printf '  [self-check] %s of 2 plants went UNCAUGHT.\n' "$fails" >&2
  exit 1
fi

uv run --quiet pytest "$@"
