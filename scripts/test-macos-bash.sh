#!/usr/bin/env bash
#
# Run the installer under the bash macOS actually ships — 3.2.57, frozen in
# 2007 — without a Mac.
#
#   bash scripts/test-macos-bash.sh
#
# WHY. `bash -n` on this machine is bash 5, which happily parses things 3.2
# does not, so a macOS-only syntax error is invisible here and lands on the
# user. That is exactly what happened: the installer completed its work and
# then died with "unexpected EOF while looking for matching quote" on the Mac,
# twice, while every local check was green.
#
# macOS itself cannot be containerised in any practical or licensed way, but
# the macOS-specific RISK here is almost entirely its ancient bash. The
# official bash:3.2 image reproduces that exactly, in about a second.

set -uo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=bash:3.2

pass=0; fail=0
ok()  { printf '  ✔ %s\n' "$*"; pass=$((pass+1)); }
bad() { printf '  ✘ %s\n' "$*"; fail=$((fail+1)); }

if ! command -v docker > /dev/null 2>&1; then
  echo "test-macos-bash: docker is not available, so the macOS bash was NOT tested." >&2
  echo "                 This is the check that catches what bash 5 cannot see." >&2
  exit 1
fi
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "  pulling $IMAGE (once, ~15MB)..."
  docker pull --quiet "$IMAGE" > /dev/null 2>&1 || { echo "test-macos-bash: cannot pull $IMAGE" >&2; exit 1; }
fi

echo "terminal-help — does it work on the bash macOS ships?"
echo "  image: $IMAGE  ($(docker run --rm $IMAGE bash --version | head -n1))"
echo

# --- 1. every bash script PARSES under 3.2 --------------------------------
scripts=$(cd "$REPO" && ls install.sh scripts/*.sh 2>/dev/null)
n=0
for f in $scripts; do
  n=$((n+1))
  if out=$(docker run --rm -v "$REPO:/w:ro" -w /w "$IMAGE" bash -n "$f" 2>&1); then
    ok "parses under bash 3.2: $f"
  else
    bad "FAILS to parse under bash 3.2: $f"
    printf '%s\n' "$out" | sed 's/^/      /'
  fi
done
echo "  ($n bash file(s) examined)"

# --- 2. the installer RUNS to completion under 3.2 ------------------------
# Parsing is not running: bash 3.2 lacks associative arrays, ${var^^}, and
# `local -n`, none of which show up in a parse check of code that avoids them
# by luck rather than by test.
out=$(docker run --rm -v "$REPO:/w:ro" "$IMAGE" sh -c '
  cp -r /w /repo && mkdir -p /home/t && cd /repo &&
  HOME=/home/t bash ./install.sh --topics git,mac --yes 2>&1; echo "EXIT=$?"' 2>&1)

printf '%s' "$out" | grep -q 'EXIT=0' \
  && ok "the installer exits 0 under bash 3.2" \
  || { bad "the installer FAILED under bash 3.2"; printf '%s\n' "$out" | tail -20 | sed 's/^/      /'; }

# bash 4 syntax (${var^^}, associative arrays, `local -n`) PARSES under 3.2 and
# fails at runtime with a message that does not necessarily stop the script —
# so exit 0 is not enough. Look for bash complaining about anything at all.
if printf '%s' "$out" | grep -qE 'bad substitution|syntax error|unexpected EOF|unbound variable|not a valid identifier'; then
  bad "bash 3.2 complained during the run:"
  printf '%s' "$out" | grep -nE 'bad substitution|syntax error|unexpected EOF|unbound variable|not a valid identifier' | sed 's/^/      /'
else
  ok "bash 3.2 reported no errors of its own"
fi

for expect in "installed 9 topics" "added the terminal-help block" "open a new shell"; do
  printf '%s' "$out" | grep -q "$expect" \
    && ok "printed: $expect" \
    || bad "did NOT print: $expect  (the script may have died before its end)"
done

# The bug that started this: a literal backslash in the tilde-shortened path.
if printf '%s' "$out" | grep -q '\\~/'; then
  bad "printed a literal backslash before ~ — \${var/#\$HOME/\\~} keeps it on 3.2"
else
  ok "the ~ in paths renders as ~, not \\~"
fi

# --- 3. and the files it wrote are the ones we expect ---------------------
out=$(docker run --rm -v "$REPO:/w:ro" "$IMAGE" sh -c '
  cp -r /w /repo && mkdir -p /home/t && cd /repo &&
  HOME=/home/t bash ./install.sh --topics git,mac --yes > /dev/null 2>&1
  ls -a /home/t; echo "---"; cat /home/t/.terminal-help/selected' 2>&1)
for f in .zshrc .zshrc-user.sh .zshrc-help.d .terminal-help; do
  printf '%s' "$out" | grep -qx "$f" && ok "created $f" || bad "did not create $f"
done
printf '%s' "$out" | grep -qx 'mac' && ok "the manifest holds the chosen topics" || bad "manifest is wrong"

# --- 4. the truncation sentinel -------------------------------------------
# The failure this project actually hit on macOS was not a bash version at all:
# a partial file read from a network share. The installer detects that itself
# now, and this proves the detector works under 3.2 too.
out=$(docker run --rm -v "$REPO:/w:ro" "$IMAGE" sh -c '
  cp -r /w /repo && cd /repo && head -c -12 install.sh > part.sh &&
  mkdir -p /home/t && HOME=/home/t bash ./part.sh --topics git --yes 2>&1' 2>&1)
# Either guard may fire first — the relaunch verifying its copy, or the
# sentinel check in the relaunched copy. Both say TRUNCATED and both refuse.
printf '%s' "$out" | grep -q 'TRUNCATED' \
  && ok "a truncated installer is caught before it does anything" \
  || { bad "a truncated installer was NOT caught"; printf '%s\n' "$out" | tail -6 | sed 's/^/      /'; }
printf '%s' "$out" | grep -q 'added the terminal-help block' \
  && bad "...but it still modified ~/.zshrc, which it must not" \
  || ok "...and it changed nothing"

echo
ver=$(docker run --rm "$IMAGE" bash --version | head -n1)
echo "  $pass passed, $fail failed, on ${ver%%(*}."
[ "$fail" -eq 0 ] || exit 1
