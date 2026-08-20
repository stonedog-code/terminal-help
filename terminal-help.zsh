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
# Start from zshrc-user.sh.example. Set TH_USER_FILE to keep it elsewhere.

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
# ui.zsh first: every other file is written in terms of its helpers.
source "$TH_HOME/lib/ui.zsh"
for _th_file in "$TH_HOME"/lib/*.zsh(N); do
    [[ "$_th_file" == */ui.zsh ]] && continue
    source "$_th_file"
done
unset _th_file

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

    [[ -r "$TH_USER_FILE" ]] && source "$TH_USER_FILE"
    TH_USER_SOURCED=1

    [[ -z $TH_QUIET ]] && th_defined user_on_load && user_on_load
    return 0
}

# --- what a new shell prints -----------------------------------------------
# One line: the installed version. Anything else you see comes from your own
# ~/.zshrc-user.sh. Set TH_QUIET=1 to silence even that.
if [[ -z $TH_QUIET ]]; then
    th_banner
fi
