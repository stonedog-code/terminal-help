#!/usr/bin/env zsh
#
# terminal-help — a reference that lives in the shell.
#
#   source /path/to/terminal-help/terminal-help.zsh
#
# Loading is silent apart from one version line. Everything else is printed
# only when you ask for it: type `get_help`.
#
# NOTHING host-specific is in this repository. The hooks below are the entire
# contract with the private half:
#
#   user.sh        gitignored, never committed. May define anything, and is
#                  expected to define some or all of:
#     connect_work / disconnect_work   your share, VPN, tunnel, jump host
#     get_user_info                    your own reference sections
#     user_on_load                     what to run on every new shell
#
# Start from user.sh.example. Set TH_USER_FILE to keep it somewhere else.

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

# --- load the private half -------------------------------------------------
# Looked for in the repo first, then ~/.config. TH_USER_FILE keeps pointing at
# the repo path when neither exists, so the "create it" hint names one place.
TH_USER_FILE="${TH_USER_FILE:-$TH_HOME/user.sh}"
_th_alt_user="$HOME/.config/terminal-help/user.sh"

if [[ -r "$TH_USER_FILE" ]]; then
    source "$TH_USER_FILE"
    TH_USER_LOADED=1
elif [[ -r "$_th_alt_user" ]]; then
    TH_USER_FILE="$_th_alt_user"
    source "$TH_USER_FILE"
    TH_USER_LOADED=1
else
    TH_USER_LOADED=""
    # Stubs, so a machine with no user.sh gets an instruction rather than
    # "command not found" — which reads as a broken install.
    connect_work() {
        th_warn "No user.sh — connect_work is not defined on this machine."
        th_row "Create it:" "cp \"$TH_HOME/user.sh.example\" \"$TH_HOME/user.sh\""
        return 1
    }
    disconnect_work() { connect_work; }
fi
unset _th_alt_user

# --- what a new shell prints -----------------------------------------------
# One line: the installed version. Anything else you see comes from your own
# user_on_load. Set TH_QUIET=1 to silence even that.
if [[ -z $TH_QUIET ]]; then
    th_banner
    th_defined user_on_load && user_on_load
fi
