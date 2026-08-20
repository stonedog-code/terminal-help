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
zsh_files=(terminal-help.zsh lib/*.zsh)
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

# --- powershell --------------------------------------------------------------
ps_files=(powershell/*.ps1)
if ! command -v pwsh > /dev/null 2>&1; then
  printf 'check-syntax: pwsh is not installed, so %s PowerShell file(s) CANNOT be checked.\n' "${#ps_files[@]}" >&2
  fail=1
else
  for f in "${ps_files[@]}"; do
    if pwsh -NoProfile -Command "
        \$e = \$null
        [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$e) > \$null
        if (\$e.Count) { \$e | ForEach-Object { Write-Error \$_ }; exit 1 }
      " > /dev/null 2>&1; then note "pwsh ok      $f"; else note "pwsh FAILED  $f"; fail=1; fi
  done
  note "pwsh: ${#ps_files[@]} file(s) parsed"
fi

total=$(( ${#zsh_files[@]} + ${#bash_files[@]} + ${#ps_files[@]} ))
if [ "$total" -eq 0 ]; then
  printf 'check-syntax: 0 files examined. A gate that inspects nothing is not a gate.\n' >&2
  exit 1
fi

if [ "$fail" -ne 0 ]; then
  printf '\ncheck-syntax: FAILED (examined %s file(s))\n' "$total" >&2
  exit 1
fi
printf '\ncheck-syntax: OK — %s file(s) parsed, all languages checked.\n' "$total"
