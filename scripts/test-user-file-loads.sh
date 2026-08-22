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
  HOME="$H" bash "$REPO/install.sh" --topics git,mac,homebrew --yes > "$TMP/install.log" 2>&1
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

# --- 6e. every command answers to _info as well as _help -------------------
# People reach for whichever word they think in, and being wrong about which
# one this tool picked is a `command not found` for something that is right
# there. Asserted as EQUALITY of output, not merely as "the name exists": a
# twin that resolves to a different function is worse than no twin.
out=$(HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic '
    TH_NO_COLOR=1
    a=$(COLUMNS=100 get_git_help); b=$(COLUMNS=100 get_git_info)
    [[ -n $a && $a == $b ]] && print TWIN_MATCHES || print TWIN_DIFFERS
    for f in get_git_info get_git_branch_info get_info get_info_topics; do
        whence -w $f > /dev/null 2>&1 || print "MISSING $f"
    done' 2>&1)
[ "$(count "$out" "TWIN_MATCHES")" -ge 1 ] \
  && ok "get_git_info prints exactly what get_git_help prints" \
  || bad "get_git_info is missing or prints something else"
if [ "$(count "$out" "MISSING")" -eq 0 ]; then
  ok "sub-sections and the framework commands have _info twins too"
else
  bad "some _info twins are undefined:"
  printf '%s\n' "$out" | grep MISSING | sed 's/^/      /'
fi

# A topic of the user's own gets its twins from the same generator — no
# special-casing, which is the point of generating them at all.
mkdir -p "$H/.zshrc-help.d"
cat > "$H/.zshrc-help.d/deploy.help.sh" <<'EOF'
# TH_TOPIC: deploy
# TH_EMOJI: 🚀
# TH_DESC:  our deploy runbook
# TH_ALSO:  get_deploy_smoke_help | 💨 | the smoke test
_th_help_deploy() { th_row "Staging:" "make deploy" }
get_deploy_smoke_help() { th_row "Smoke:" "make smoke" }
EOF
out=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'whence -w get_deploy_info get_deploy_smoke_info' 2>&1)
[ "$(count "$out" "function")" -eq 2 ] \
  && ok "a user's own topic and its sub-section both get _info twins" \
  || bad "a user topic did not get its twins"

# THE GUARD THAT MATTERS. Generating the twin means eval'ing a name that came
# out of a header comment in a file terminal-help did not write. If that name
# is not validated first, a TH_ALSO line is arbitrary code at shell startup.
cat > "$H/.zshrc-help.d/deploy.help.sh" <<EOF
# TH_TOPIC: deploy
# TH_EMOJI: 🚀
# TH_DESC:  our deploy runbook
# TH_ALSO:  get_x_help; touch $TMP/PWNED; : | 💀 | injection
_th_help_deploy() { th_row "Staging:" "make deploy" }
EOF
rm -f "$TMP/PWNED"
out=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'print DONE' 2>&1)
if [ -e "$TMP/PWNED" ]; then
  bad "a TH_ALSO header executed a command — the twin generator eval's unvalidated names"
else
  ok "a TH_ALSO name that is not a plain function name is refused, not eval'd"
fi
[ "$(count "$out" "cannot make an _info twin")" -ge 1 ] \
  && ok "...and it says so rather than failing silently" \
  || bad "the rejection was silent"
rm -f "$H/.zshrc-help.d/deploy.help.sh"

# --- 6e2. a TH_ALSO line that forgot its pipes ----------------------------
# The format is  function | emoji | description, and the parsing slices on
# `|` — which cannot tell a missing field from a present one, because
# ${x%%|*} and ${x#*|} BOTH return the whole string when there is no pipe. So
# an author who forgot the pipes got the function name rendered as its own
# emoji and its own description, and nothing said why. TH_ALSO is a documented
# extension point for user files, so the person hitting this is writing their
# first help file — silence is the worst possible answer for them.
cat > "$H/.zshrc-help.d/nopipe.help.sh" <<'EOF'
# TH_TOPIC: nopipe
# TH_EMOJI: 🧪
# TH_DESC:  a topic whose TH_ALSO line forgot its pipes
# TH_ALSO:  get_nopipe_sub_help
_th_help_nopipe() { th_row "X:" "NOPIPE_BODY" }
get_nopipe_sub_help() { th_row "Y:" "SUB_BODY" }
EOF
out=$(HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic 'TH_NO_COLOR=1 COLUMNS=100 get_help' 2>/dev/null)
# The index row, not the load-time warning: th_warn prints to stdout too, and
# it necessarily contains the same function name.
row=$(printf '%s\n' "$out" | grep -E '^[[:space:]]*get_nopipe_sub_help' | head -1)
# Twice is right — once as the command, once as the fallback description.
# Three times is the bug: the name was used as the emoji as well.
n=$(printf '%s\n' "$row" | grep -o 'get_nopipe_sub_help' | wc -l | tr -d ' ')
if [ "$n" -le 2 ] && [ "$(count "$row" '📄')" -ge 1 ]; then
  ok "a TH_ALSO line with no pipes falls back to a default emoji, not the function name"
else
  bad "a TH_ALSO line with no pipes renders the function name as its own emoji and description"
  note "the row was: $row"
fi
out=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'print DONE' 2>&1)
{ [ "$(count "$out" "nopipe.help.sh")" -ge 1 ] && [ "$(count "$out" "get_nopipe_sub_help")" -ge 1 ]; } \
  && ok "...and says so at load, naming the file and quoting the line" \
  || bad "a TH_ALSO line with no pipes was accepted silently"

# ...while a WELL-FORMED line stays silent, which is not as obvious as it
# sounds: zsh's `local` PRINTS a parameter that already exists, so declaring
# the three fields bare rather than with their values dumped `ae=…`/`ad=…` into
# every shell from the second TH_ALSO line of any file onwards. That was
# introduced while fixing the above and caught by eye — every tier stayed
# green, because they all grep for content and none of them looks for noise.
cat > "$H/.zshrc-help.d/nopipe.help.sh" <<'EOF'
# TH_TOPIC: nopipe
# TH_EMOJI: 🧪
# TH_DESC:  a topic with two well-formed TH_ALSO lines
# TH_ALSO:  get_nopipe_a_help | 🅰 | the first sub-section
# TH_ALSO:  get_nopipe_b_help | 🅱 | the second sub-section
_th_help_nopipe() { th_row "X:" "NOPIPE_BODY" }
EOF
out=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'print DONE' 2>&1)
noise=$(printf '%s\n' "$out" | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | head -3)
if [ -z "$noise" ]; then
  ok "a well-formed TH_ALSO line adds nothing to what a new shell prints"
else
  bad "loading a help file dumped parameters into the shell:"
  printf '%s\n' "$noise" | sed 's/^/      /'
fi
rm -f "$H/.zshrc-help.d/nopipe.help.sh"

# --- 6f. a related topic is NAMED by default and printed only under --all --
# get_mac_help used to end by calling get_homebrew_help outright: at 100 columns
# it was 132 lines, of which 69 were Homebrew and 21 were macOS. Asking for
# macOS help and getting mostly a package manager is not help, and there was no
# way to decline it.
mac=$(HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic 'TH_NO_COLOR=1 COLUMNS=100 get_mac_help' 2>&1)
all=$(HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic 'TH_NO_COLOR=1 COLUMNS=100 get_mac_help --all' 2>&1)

# "brew bundle dump" appears only in the homebrew topic's body, so it is a
# content probe rather than a word that might turn up in a cross-reference.
if [ "$(count "$mac" "brew bundle dump")" -eq 0 ]; then
  ok "get_mac_help prints macOS, not Homebrew"
else
  bad "get_mac_help still inlines the whole homebrew topic"
fi
# `brew leaves` is in homebrew's SUMMARY; this probe used to be `brew bundle
# dump`, which is now homebrew DETAIL. The flip is deliberate and is the
# specification changing, not the test being loosened: --all shows a neighbour
# at summary depth, so probing for the neighbour's detail would assert the
# opposite of what --all is now for. The old string still has a home — the
# assertion two blocks down uses it to prove the neighbour is NOT expanded.
[ "$(count "$all" "brew leaves")" -ge 1 ] \
  && ok "get_mac_help --all does print the related topic's summary" \
  || bad "--all did not bring in the related topic"
[ "$(count "$all" "Reproducing a machine")" -eq 0 ] \
  && ok "...at SUMMARY depth — the neighbour is not printed in full" \
  || bad "--all printed the whole related topic, not its summary"

# Named, not silently dropped: the whole justification for deferring it is that
# the name IS the command, so the name has to be there.
[ "$(count "$mac" "get_homebrew_help")" -ge 1 ] \
  && ok "...and names get_homebrew_help so it can still be found" \
  || bad "the related topic is not printed AND not named — it just vanished"

# The twin has to forward its arguments, or --all works on one spelling only.
out=$(HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic 'TH_NO_COLOR=1 COLUMNS=100 get_mac_info --all' 2>&1)
[ "$(count "$out" "brew leaves")" -ge 1 ] \
  && ok "get_mac_info --all works too — the _info twin forwards arguments" \
  || bad "the _info twin swallowed --all"

# An unknown flag must be reported. A tool that ignores what you typed teaches
# you that it did what you asked.
out=$(HOME="$H" ZDOTDIR="$H" zsh -ic 'TH_NO_COLOR=1 get_mac_help --everything; print "rc=$?"' 2>&1)
{ [ "$(count "$out" "I do not know the option")" -ge 1 ] && [ "$(count "$out" "rc=2")" -ge 1 ]; } \
  && ok "an unknown option is reported and exits non-zero, not swallowed" \
  || bad "an unknown option was ignored"

# Two topics that name each other is a reasonable thing to write, and under
# --all it is a cycle. It must terminate, print each body once, and not shout.
mkdir -p "$H/.zshrc-help.d"
cat > "$H/.zshrc-help.d/alpha.help.sh" <<'EOF'
# TH_TOPIC: alpha
# TH_EMOJI: 🅰
# TH_DESC:  alpha
# TH_RELATED: beta
_th_help_alpha() { th_row "A:" "ALPHA_BODY" }
EOF
cat > "$H/.zshrc-help.d/beta.help.sh" <<'EOF'
# TH_TOPIC: beta
# TH_EMOJI: 🅱
# TH_DESC:  beta
# TH_RELATED: alpha
_th_help_beta() { th_row "B:" "BETA_BODY" }
EOF
out=$($TIMEOUT 15 env HOME="$H" ZDOTDIR="$H" COLUMNS=100 zsh -ic 'TH_NO_COLOR=1 COLUMNS=100 get_alpha_help --all' 2>&1)
rc=$?
if [ "$rc" -eq 124 ]; then
  bad "two topics naming each other hung the shell under --all"
elif [ "$(count "$out" "ALPHA_BODY")" -eq 1 ] && [ "$(count "$out" "BETA_BODY")" -eq 1 ]; then
  ok "a TH_RELATED cycle under --all prints each topic exactly once"
else
  bad "a TH_RELATED cycle printed alpha $(count "$out" "ALPHA_BODY")x, beta $(count "$out" "BETA_BODY")x — expected 1 and 1"
fi
# ...and QUIETLY. Two topics naming each other is a reasonable thing to write,
# not a mistake, so it must not produce the warning that exists for a hook
# re-entering its own topic. Without the skip in th_show_related the guard
# still stops the loop — but it stops it by shouting at someone who did
# nothing wrong, and a warning that fires on correct usage is one people learn
# to scroll past.
[ "$(count "$out" "refusing to re-enter")" -eq 0 ] \
  && ok "...and says nothing, because naming each other is not a mistake" \
  || bad "a legitimate TH_RELATED cycle triggered the re-entrancy warning"
rm -f "$H/.zshrc-help.d/alpha.help.sh" "$H/.zshrc-help.d/beta.help.sh"

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
