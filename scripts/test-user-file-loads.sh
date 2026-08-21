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

# THE ENVIRONMENT MUST NOT LEAK IN. terminal-help EXPORTS TH_HOME, TH_VERSION
# and TH_USER_FILE, so every shell on a machine where it is installed hands
# them to its children — including the zsh this suite starts. TH_USER_FILE is
# honoured when already set (that is the documented "keep it elsewhere"
# feature), so the shell under test read the developer's REAL settings file
# instead of the throwaway one, found no marker in it, and failed the old-block
# assertion on a perfectly healthy tree.
#
# Measured 2026-08-20 on identical code: 16 passed / 1 failed on a machine with
# terminal-help installed, 17 / 0 in CI, which has no TH_* set. That is the
# worst shape a red can take — it looks like the branch, and it is the suite.
unset TH_HOME TH_VERSION TH_USER_FILE TH_SELECTED TH_USER_HELP_DIR \
      TH_QUIET TH_NO_COLOR TH_NO_RELAUNCH

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
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

# The recursion assertions below have to bound a shell that may never return.
# Same rule as zsh: a missing tool is a failure, because the alternative is a
# suite that hangs forever in CI, or one that "skips" the only assertion
# standing between a user file and an unusable shell.
if command -v timeout > /dev/null 2>&1; then
  TIMEOUT=timeout
elif command -v gtimeout > /dev/null 2>&1; then   # coreutils on macOS
  TIMEOUT=gtimeout
else
  echo "test-user-file-loads: no timeout(1), so the recursion assertions cannot" >&2
  echo "                      be bounded and were NOT run. Install coreutils" >&2
  echo "                      (brew install coreutils gives gtimeout)." >&2
  exit 1
fi

TMP=$(mktemp -d)
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
cp "$H/.zshrc" "$TMP/zshrc.installed"     # pristine copy: later tests overwrite it
grep -q 'terminal-help >>>' "$H/.zshrc" || { bad "install.sh did not write the block"; cat "$TMP/install.log"; exit 1; }

if [ "$SELF_CHECK" -eq 1 ]; then
  # Reintroduce the v0.12.0 bug in the INSTALLED copy: the loader no longer
  # loads the settings file on its own. With the current block this must still
  # pass (the block calls th_source_user); with an old block it must FAIL.
  sed -i.bak '/|| th_source_user$/d' "$H/.terminal-help/terminal-help.zsh"
  echo "  [self-check] removed the loader's fallback from the installed runtime"
  echo
fi

# --- 0. the suite is hermetic ---------------------------------------------
# Asserted rather than assumed, because the leak above is invisible: every
# other assertion still runs, and one of them simply reports the wrong answer.
# Probed by sourcing the RUNTIME directly, with no rc block: the installed
# block sets `export TH_USER_FILE=...` itself, which masks an inherited value
# and made the first version of this assertion pass with the leak still there.
# The path that honours the environment is TH_USER_FILE="${TH_USER_FILE:-...}"
# in terminal-help.zsh, and that is what this reaches.
out=$(HOME="$H" ZDOTDIR="$H" zsh -f -c 'source "$HOME/.terminal-help/terminal-help.zsh" > /dev/null 2>&1; print "TH_USER_FILE=$TH_USER_FILE"' 2>&1)
case "$out" in
  *"TH_USER_FILE=$H/"*)
    ok "the shell under test resolves ITS OWN settings file, not yours" ;;
  *)
    bad "the environment leaked into the throwaway HOME"
    note "expected TH_USER_FILE under $H, got:"; printf '%s\n' "$out" | sed 's/^/      /' ;;
esac

# --- 1. the exact thing the user typed ------------------------------------
out=$(run_zsh --source-only)
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
out=$(run_zsh)
[ "$(count "$out" "$MARKER top-level")" -ge 1 ] \
  && ok "an interactive zsh printed it too" || bad "an interactive zsh printed nothing"

# --- 3. exactly once ------------------------------------------------------
n=$(count "$out" "$MARKER top-level")
[ "$n" -eq 1 ] && ok "loaded exactly once (not double-sourced)" \
               || bad "loaded $n times — the file is being sourced more than once"

# --- 4. the definitions survive -------------------------------------------
out=$(HOME="$H" ZDOTDIR="$H" zsh -i -c "${MARKER}_fn; alias ${MARKER}_alias" 2>&1)
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
out=$(run_zsh --source-only)
if [ "$(count "$out" "$MARKER top-level")" -ge 1 ]; then
  ok "an OLD block with no th_source_user line still loads your file"
else
  bad "an old block loads nothing — the v0.12.0 regression is back"
  note "this is the exact failure: version line prints, your file does not"
fi

# --- 5b. RE-SOURCING ~/.zshrc must print your settings again.
# The idempotence guard is per LOAD, not per shell. It used to survive into the
# next `source ~/.zshrc`, so re-sourcing your rc printed the version line and
# nothing else — terminal-help reloaded, your settings did not. Three separate
# "it still does not print" reports were looking at exactly this.
write_user_file
cp "$TMP/zshrc.installed" "$H/.zshrc"     # test 5 replaced it with an old block
out=$(HOME="$H" ZDOTDIR="$H" zsh -i -c 'source ~/.zshrc' 2>&1)
n=$(count "$out" "$MARKER top-level")
[ "$n" -ge 2 ] \
  && ok "re-sourcing ~/.zshrc prints your settings again (seen $n times: startup + re-source)" \
  || bad "re-sourcing ~/.zshrc printed your settings $n time(s) — expected 2"

# --- 6. a failing LAST command is not an abort, and must not be reported as
#        one; a real abort must be. 126 is the abort signature, measured.
cat > "$H/.zshrc-user.sh" <<EOF
print "$MARKER top-level"
user_on_load() { print "$MARKER from user_on_load" }
false
EOF
out=$(run_zsh)
if [ "$(count "$out" "STOPPED EARLY")" -eq 0 ]; then
  ok "a failing last command does not produce a scary 'stopped early' warning"
else
  bad "a benign failure was reported as an abort"
fi
[ "$(count "$out" "$MARKER top-level")" -ge 1 ] \
  && ok "...and the file still loaded" || bad "the file did not load"

# A builtin misused at file scope: this genuinely stops the file, and the
# things defined below it must be missing.
cat > "$H/.zshrc-user.sh" <<EOF
print "$MARKER top-level"
private file, so it can be as specific as you like.
${MARKER}_below() { print "should not exist" }
EOF
out=$(run_zsh)
[ "$(count "$out" "STOPPED EARLY")" -ge 1 ] \
  && ok "a real abort IS reported" || bad "a real abort was not reported"
out=$(HOME="$H" ZDOTDIR="$H" zsh -i -c "whence -w ${MARKER}_below" 2>&1)
[ "$(count "$out" "function")" -eq 0 ] \
  && ok "...and what was below the failing line is indeed missing" \
  || bad "the abort test is not actually aborting"
write_user_file   # restore for the checks below

# --- 6b. narrow terminals: a description must wrap INTO its own column ----
# At 84x40 the description used to wrap at the terminal edge and continue at
# column 0, under the labels, so the two columns stopped being columns. The
# rule: nothing we emit should be wider than the terminal unless it is a single
# unbreakable word (a command you have to be able to copy).
for cols in 60 84; do
  out=$(HOME="$H" ZDOTDIR="$H" COLUMNS=$cols zsh -i -c 'TH_NO_COLOR=1 get_git_help; TH_NO_COLOR=1 get_help' 2>/dev/null)
  # Measured in zsh, with ${(m)#line} — display width. awk counts bytes, which
  # makes every em-dash and arrow look three columns wide.
  bad_lines=$(printf '%s\n' "$out" | HOME="$H" COLUMNS=$cols zsh -c '
    integer w=${1:-80} n=0
    while IFS= read -r line; do
      (( n++ ))
      (( ${(m)#line} > w )) || continue
      # Could it have broken? Only complain if there is a space past the edge.
      rest=${line[$w,-1]}
      [[ $rest == *" "* ]] && print -r -- "$n: $line"
    done' -- "$cols" | head -3)
  if [ -z "$bad_lines" ]; then
    ok "at ${cols} columns, nothing wrapped at the terminal edge"
  else
    bad "at ${cols} columns, lines exceed the width with breakable spaces:"
    printf '%s\n' "$bad_lines" | sed 's/^/      /'
  fi
done

# --- 6c. off a tty, COLUMNS is 0 rather than empty -------------------------
# ${COLUMNS:-80} does not catch a zero, so th_wrap was called with a NEGATIVE
# width and every th_row emitted one word per line: get_mac_help went from 132
# lines to 787. The assertion is a comparison rather than a magic number —
# piped output and an 80-column terminal must lay out identically, which is
# what README's "get_git_help > notes.txt comes out clean" has always claimed.
piped=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'TH_NO_COLOR=1 get_git_help' 2>/dev/null | wc -l | tr -d ' ')
at80=$(HOME="$H" ZDOTDIR="$H" COLUMNS=80 zsh -ic 'TH_NO_COLOR=1 COLUMNS=80 get_git_help' 2>/dev/null | wc -l | tr -d ' ')
if [ "$piped" = "$at80" ]; then
  ok "piped output lays out like an 80-column terminal ($piped lines both ways)"
else
  bad "piped output is $piped lines but an 80-column terminal gives $at80"
  note "COLUMNS is 0 off a tty; th_cols must treat that as no terminal, not as a width"
fi

# --- 6d. a topic must not be able to print itself forever ------------------
# One line in a user file used to hang the shell with no exit but Ctrl-C.
# Measured on the unguarded code: 44,495 lines in 8 seconds. The extension used
# here reaches the topic INDIRECTLY, through a wrapper, because that is the
# form th_extend's own check cannot see — this asserts the loop is closed in
# th_show_topic, not merely refused at one spelling.
mkdir -p "$H/.zshrc-help.d"
cat > "$H/.zshrc-help.d/loop.help.sh" <<'EOF'
_th_ext_reenters() { get_git_help }
th_extend git _th_ext_reenters
EOF
out=$($TIMEOUT 15 env HOME="$H" ZDOTDIR="$H" zsh -ic 'TH_NO_COLOR=1 get_git_help' 2>&1)
rc=$?
if [ "$rc" -eq 124 ]; then
  bad "a self-referencing extension hung the shell — it had to be killed"
  note "this is the reported 'loops forever until Ctrl-C'"
elif [ "$(count "$out" "refusing to re-enter")" -ge 1 ]; then
  ok "a self-referencing extension is refused instead of looping forever"
else
  bad "the shell returned, but nothing said why the topic did not re-enter"
  note "the guard must SAY something: silence here is indistinguishable from"
  note "the extension simply not having loaded"
fi

# ...and the obvious spelling of the same mistake is caught earlier, at
# registration, where the warning can still name the file being read.
cat > "$H/.zshrc-help.d/loop.help.sh" <<'EOF'
th_extend git get_git_help
EOF
out=$($TIMEOUT 15 env HOME="$H" ZDOTDIR="$H" zsh -ic 'print DONE' 2>&1)
[ "$(count "$out" "print itself forever")" -ge 1 ]   && ok "th_extend <topic> get_<topic>_help is refused at registration"   || bad "th_extend accepted a topic's own entry point as one of its hooks"
rm -f "$H/.zshrc-help.d/loop.help.sh"

# --- 7. quiet mode loads settings, it only silences the banner ------------
out=$(HOME="$H" ZDOTDIR="$H" TH_QUIET=1 zsh -i -c 'print DONE' 2>&1)
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
