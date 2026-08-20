#!/usr/bin/env bash
#
# Proves the thing that broke twice: sourcing ~/.zshrc must load
# ~/.zshrc-user.sh and print what is in it.
#
#   bash scripts/test-user-file-loads.sh
#   bash scripts/test-user-file-loads.sh --self-check   # prove the test can fail
#
# Everything happens in a throwaway HOME. Your own ~/.zshrc, ~/.zshrc-user.sh
# and ~/.terminal-help are never read or written.
#
# WHY THIS EXISTS. Two separate faults produced the identical symptom — the
# version line printed and nothing of the user's did:
#
#   v0.6.0  the installed block hardcoded the clone's path, so on any other
#           machine the source failed, th_source_user was never defined, and
#           the settings file was never loaded.
#   v0.12.0 a block written by an older installer had no th_source_user line,
#           and the loader would not load the file on its own.
#
# Both were found by hand, twice, from the same confusing symptom. A test that
# starts a real zsh and looks for a real marker costs a second and ends that.

set -uo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SELF_CHECK=0
[ "${1:-}" = "--self-check" ] && SELF_CHECK=1

MARKER="THTEST_MARKER_9F2A"
pass=0; fail=0
ok()   { printf '  ✔ %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  ✘ %s\n' "$*"; fail=$((fail+1)); }
note() { printf '    %s\n' "$*"; }

# A missing zsh is a FAILURE, not a skip: a test that quietly checks nothing is
# worse than no test, because it reports success.
if ! command -v zsh > /dev/null 2>&1; then
  echo "test-user-file-loads: zsh is not installed, so NOTHING was tested." >&2
  echo "                      Install it (apt-get install zsh / brew install zsh)." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
H="$TMP/home"; mkdir -p "$H"

# A settings file that prints in three distinguishable ways: at source time,
# from the user_on_load hook, and by defining something we can call afterwards.
write_user_file() {
  cat > "$H/.zshrc-user.sh" <<EOF
print "$MARKER top-level"
alias ${MARKER}_alias="echo hello"
${MARKER}_fn() { print "$MARKER from a function" }
user_on_load() { print "$MARKER from user_on_load" }
EOF
}

install_into_home() {
  HOME="$H" bash "$REPO/install.sh" --topics git --yes > "$TMP/install.log" 2>&1
}

# Run a real zsh in that HOME. `--source-only` uses exactly what a person types
# when they say "source .zshrc"; the default is a real interactive shell.
run_zsh() {
  if [ "${1:-}" = "--source-only" ]; then
    HOME="$H" ZDOTDIR="$H" zsh -f -c "source '$H/.zshrc'; print DONE" 2>&1
  else
    HOME="$H" ZDOTDIR="$H" zsh -i -c 'print DONE' 2>&1
  fi
}

count() { printf '%s' "$1" | grep -c "$2" || true; }

echo "terminal-help — does ~/.zshrc load ~/.zshrc-user.sh?"
echo "  repo:  $REPO"
echo "  HOME:  $H  (throwaway)"
echo

write_user_file
install_into_home
grep -q 'terminal-help >>>' "$H/.zshrc" || { bad "install.sh did not write the block"; cat "$TMP/install.log"; exit 1; }

if [ "$SELF_CHECK" -eq 1 ]; then
  # Reintroduce the v0.12.0 bug in the INSTALLED copy: the loader no longer
  # loads the settings file on its own. With the current block this must still
  # pass (the block calls th_source_user); with an old block it must FAIL.
  sed -i.bak '/|| th_source_user$/d' "$H/.terminal-help/terminal-help.zsh"
  echo "  [self-check] removed the loader's fallback from the installed runtime"
  echo
fi

# --- 1. the exact thing the user typed ------------------------------------
out="$(run_zsh --source-only)"
if [ "$(count "$out" "$MARKER top-level")" -ge 1 ]; then
  ok "source ~/.zshrc printed a top-level line from ~/.zshrc-user.sh"
else
  bad "source ~/.zshrc printed NOTHING from ~/.zshrc-user.sh"
  note "output was:"; printf '%s\n' "$out" | sed 's/^/      /'
fi
[ "$(count "$out" "$MARKER from user_on_load")" -ge 1 ] \
  && ok "user_on_load ran" || bad "user_on_load did not run"
[ "$(count "$out" "🧰 terminal-help")" -ge 1 ] \
  && ok "the version line still prints" || bad "the version line is missing"

# --- 2. a real interactive shell ------------------------------------------
out="$(run_zsh)"
[ "$(count "$out" "$MARKER top-level")" -ge 1 ] \
  && ok "an interactive zsh printed it too" || bad "an interactive zsh printed nothing"

# --- 3. exactly once ------------------------------------------------------
n="$(count "$out" "$MARKER top-level")"
[ "$n" -eq 1 ] && ok "loaded exactly once (not double-sourced)" \
               || bad "loaded $n times — the file is being sourced more than once"

# --- 4. the definitions survive -------------------------------------------
out="$(HOME="$H" ZDOTDIR="$H" zsh -i -c "${MARKER}_fn; alias ${MARKER}_alias" 2>&1)"
[ "$(count "$out" "$MARKER from a function")" -ge 1 ] \
  && ok "a function defined in the settings file is callable" || bad "the function is not defined"
[ "$(count "$out" "${MARKER}_alias")" -ge 1 ] \
  && ok "an alias defined in the settings file survives" || bad "the alias is not defined"

# --- 5. THE REGRESSION: a block from an older installer -------------------
# No th_source_user line. This is what shipped before v0.5.0, and what left a
# real machine printing only the version line at v0.12.0.
cat > "$H/.zshrc" <<EOF
# >>> terminal-help >>>
export TH_HOME="\$HOME/.terminal-help"
source "\$TH_HOME/terminal-help.zsh"
# <<< terminal-help <<<
EOF
out="$(run_zsh --source-only)"
if [ "$(count "$out" "$MARKER top-level")" -ge 1 ]; then
  ok "an OLD block with no th_source_user line still loads your file"
else
  bad "an old block loads nothing — the v0.12.0 regression is back"
  note "this is the exact failure: version line prints, your file does not"
fi

# --- 6. quiet mode loads settings, it only silences the banner ------------
out="$(HOME="$H" ZDOTDIR="$H" TH_QUIET=1 zsh -i -c 'print DONE' 2>&1)"
[ "$(count "$out" "$MARKER top-level")" -ge 1 ] \
  && ok "TH_QUIET=1 still loads your settings" || bad "TH_QUIET=1 skipped your settings"
[ "$(count "$out" "🧰 terminal-help")" -eq 0 ] \
  && ok "TH_QUIET=1 silences the banner" || bad "TH_QUIET=1 did not silence the banner"

echo
echo "  $pass passed, $fail failed, over $((pass+fail)) assertions in a throwaway HOME."

if [ "$SELF_CHECK" -eq 1 ]; then
  if [ "$fail" -gt 0 ]; then
    echo "  [self-check] the suite FAILED with the bug planted, which is correct."
    exit 0
  fi
  echo "  [self-check] the suite passed with the bug planted — IT PROVES NOTHING." >&2
  exit 1
fi

[ "$fail" -eq 0 ] || exit 1
