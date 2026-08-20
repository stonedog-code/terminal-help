#!/usr/bin/env zsh
#
# terminal-help — a reference that lives in the shell.
#
#   source /path/to/terminal-help/terminal-help.zsh
#
# Loading is silent apart from one version line. Everything else is printed
# only when you ask for it: type `get_help`.
#
# NOTHING host-specific is in this repository. Your own settings — aliases,
# exports, hostnames, whatever you like — go in ~/.zshrc-user.sh, which lives
# beside your ~/.zshrc and is loaded by th_source_user (see below). Two
# optional function names are the entire contract:
#
#     get_user_info     your own reference sections, printed on demand
#     user_on_load      what to run on every new shell
#
# The file the installer creates carries its own instructions in comments.
# Set TH_USER_FILE to keep it somewhere else.

# --- where am I ------------------------------------------------------------
# %x is the file currently being sourced; :A resolves symlinks, :h takes the
# directory. This is what lets the repo be cloned anywhere, or symlinked.
TH_HOME="${TH_HOME:-${${(%):-%x}:A:h}}"
export TH_HOME

if [[ -r "$TH_HOME/VERSION" ]]; then
    TH_VERSION="$(<"$TH_HOME/VERSION")"
else
    TH_VERSION="unknown"
fi
export TH_VERSION

# --- load the help ---------------------------------------------------------
# lib/ is machinery. help/<category>/<topic>.help.sh is content, and every file
# has the same shape whatever it is about — a header declaring the topic, and a
# _th_help_<topic> function. See lib/topics.zsh.
source "$TH_HOME/lib/ui.zsh"
source "$TH_HOME/lib/topics.zsh"
source "$TH_HOME/lib/help.zsh"
source "$TH_HOME/lib/versions.zsh"
source "$TH_HOME/lib/doctor.zsh"

# Everything is installed; the manifest decides what LOADS. That is what makes
# `th_topics enable mac` work months later on a machine where the clone this
# was installed from is long gone.
TH_SELECTED="${TH_SELECTED:-$TH_HOME/selected}"
typeset -ga _th_want
_th_want=(${(f)"$(th_selected_topics)"})

for _th_file in "$TH_HOME"/help/*/*.help.sh(N); do
    _th_cat=${${_th_file:h}:t}
    [[ $_th_cat == user ]] && continue          # user files load below, after these
    _th_name=$(th_header_field "$_th_file" TH_TOPIC) || continue
    # An empty manifest means "everything" — a fresh install with no selection
    # yet should be useful rather than blank.
    (( ${#_th_want} )) && (( ! ${_th_want[(I)$_th_name]} )) && continue
    th_load_topic_file "$_th_file" "$_th_cat"
done

# --- your own help files ---------------------------------------------------
# help/user/ is a SYMLINK to ~/.zshrc-help.d — the path you were promised is
# inside the tree, while the bytes live outside it. The installer replaces the
# shipped categories on every upgrade, and a symlink is deleted by that, not
# followed: your files cannot be caught in the blast radius even if the
# exclusion is one day got wrong.
#
# Anything below help/user/ is loaded, at any depth, so you can keep folders:
#   ~/.zshrc-help.d/work/deploy.help.sh
#   ~/.zshrc-help.d/extensions/git.help.sh    <- adds to the built-in git topic
TH_USER_HELP_DIR="${TH_USER_HELP_DIR:-${ZDOTDIR:-$HOME}/.zshrc-help.d}"
typeset -ga TH_USER_TOPICS

if [[ -d "$TH_USER_HELP_DIR" ]]; then
    for _th_file in "$TH_USER_HELP_DIR"/**/*.help.sh(N); do
        _th_name=$(th_header_field "$_th_file" TH_TOPIC 2>/dev/null)
        if [[ -n $_th_name ]]; then
            th_load_topic_file "$_th_file" "user" && TH_USER_TOPICS+=("$_th_name")
        else
            # No header: an extension, or a plain file of functions. Either way
            # sourcing it is what it asked for.
            source "$_th_file"
        fi
    done
fi
unset _th_file _th_cat _th_name

alias help_me=get_help

# --- the private half ------------------------------------------------------
# Your own settings live in ~/.zshrc-user.sh — OUTSIDE this repository, beside
# the ~/.zshrc that loads it. Nothing here knows your hostnames.
#
# th_source_user is what loads it, and the installed ~/.zshrc block calls it by
# name so the contract is visible where people look for it. Sourcing this file
# by hand? Call th_source_user yourself afterwards.
TH_USER_FILE="${TH_USER_FILE:-${ZDOTDIR:-$HOME}/.zshrc-user.sh}"

th_source_user() {
    [[ -n $TH_USER_SOURCED ]] && return 0      # idempotent: never load twice

    # A zsh error mid-file ABORTS the rest of it: everything below the bad line
    # is never defined and never runs, and the only clue is one error line that
    # scrolls away. `source` reports it, so check.
    TH_USER_STATUS=0
    if [[ -r "$TH_USER_FILE" ]]; then
        source "$TH_USER_FILE" || TH_USER_STATUS=$?
    fi
    TH_USER_SOURCED=1

    if (( TH_USER_STATUS )); then
        th_warn "${TH_USER_FILE:t} stopped early (exit $TH_USER_STATUS) — everything"
        th_text "below the failing line was not loaded. Run: th_doctor"
    fi

    [[ -z $TH_QUIET ]] && th_defined user_on_load && user_on_load
    return 0
}

# --- what a new shell prints -----------------------------------------------
# One line: the installed version. Anything else you see comes from your own
# ~/.zshrc-user.sh. Set TH_QUIET=1 to silence even that.
if [[ -z $TH_QUIET ]]; then
    th_banner
fi
