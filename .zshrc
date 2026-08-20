#!/usr/bin/env zsh
#
# An example ~/.zshrc, if you would rather symlink one than let the installer
# edit the one you have:
#
#   ln -s /path/to/terminal-help/.zshrc ~/.zshrc
#
# YOUR OWN SETTINGS DO NOT GO IN HERE. This file is in git; put aliases,
# exports, PATH entries and the get_user_info / user_on_load hooks in
# ~/.zshrc-user.sh, which is loaded on the last line below and which no
# upgrade will ever touch. Start from zshrc-user.sh.example.

export TH_HOME="${${(%):-%x}:A:h}"
export TH_USER_FILE="${ZDOTDIR:-$HOME}/.zshrc-user.sh"

source "$TH_HOME/terminal-help.zsh"   # the reference help
th_source_user                        # your settings, from $TH_USER_FILE
