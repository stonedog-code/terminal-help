#!/usr/bin/env bash
# check-syntax.sh — parse every shell file in the repo, in its own language.
#
# This repo ships no tests, and it cannot have meaningful ones: the code's whole
# job is to print a cheat-sheet into an interactive terminal. What it CAN have
# is a guarantee that nothing here is syntactically broken — which matters more
# than usual, because a broken lib/*.zsh is sourced from someone's ~/.zshrc and
# breaks their shell, not a test run.
#
# Each language is parsed by its own parser. `bash -n` is NOT a substitute for
# `zsh -n`: terminal-help.zsh and lib/ui.zsh use zsh-only expansions such as
# ${${(%):-%x}:A:h}, which bash rejects as a syntax error even though they are
# correct zsh.
#
# A MISSING PARSER IS A FAILURE, NOT A SKIP. Silently skipping the zsh checks
# on a machine without zsh is precisely how a gate reports green over an empty
# set, so this exits non-zero and says which tool is absent.

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
note() { printf '  %s\n' "$*"; }

# --- zsh ---------------------------------------------------------------------
# help/*.help.sh is CONTENT, and content is where a typo actually lands. When
# those files moved out of lib/ this glob stopped matching them and the gate
# quietly went from 13 files to 7 while still printing OK — the exact
# green-over-an-empty-set failure this repo's rules warn about. The count in
# the summary is what caught it, which is why the count is printed.
zsh_files=(terminal-help.zsh lib/*.zsh help/*/*.help.sh)
if ! command -v zsh > /dev/null 2>&1; then
  printf 'check-syntax: zsh is not installed, so %s zsh file(s) CANNOT be checked.\n' "${#zsh_files[@]}" >&2
  printf '              Install it (apt-get install zsh / brew install zsh) — a skipped\n' >&2
  printf '              check is not a passed check.\n' >&2
  fail=1
else
  for f in "${zsh_files[@]}"; do
    if zsh -n "$f" 2>/dev/null; then note "zsh  ok      $f"; else note "zsh  FAILED  $f"; zsh -n "$f"; fail=1; fi
  done
  note "zsh: ${#zsh_files[@]} file(s) parsed"
fi

# --- bash --------------------------------------------------------------------
bash_files=(install.sh scripts/*.sh)
for f in "${bash_files[@]}"; do
  if bash -n "$f" 2>/dev/null; then note "bash ok      $f"; else note "bash FAILED  $f"; bash -n "$f"; fail=1; fi
done
note "bash: ${#bash_files[@]} file(s) parsed"

# PowerShell used to be checked here. terminal-help no longer ships a
# PowerShell runtime — PowerShell is a help TOPIC now (help/powershell/), and
# that file is zsh like every other, checked by the zsh pass above.

# bash 3.2 (macOS) used to be approximated here by grepping for a quoting
# pattern. That guess is retired: scripts/test-macos-bash.sh now parses and RUNS
# these scripts under the real bash:3.2 image, which is both stricter and
# honest. The grep produced false positives on lines 3.2 accepts, and a check
# that cries wolf gets ignored — the same failure this project has already
# fixed twice in the doctor.

total=$(( ${#zsh_files[@]} + ${#bash_files[@]} ))
if [ "$total" -eq 0 ]; then
  printf 'check-syntax: 0 files examined. A gate that inspects nothing is not a gate.\n' >&2
  exit 1
fi

if [ "$fail" -ne 0 ]; then
  printf '\ncheck-syntax: FAILED (examined %s file(s))\n' "$total" >&2
  exit 1
fi
printf '\ncheck-syntax: OK — %s file(s) parsed, all languages checked.\n' "$total"
