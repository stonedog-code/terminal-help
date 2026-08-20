#!/usr/bin/env zsh
#
# An example ~/.zshrc, for symlinking the whole thing:
#
#   ln -s /path/to/terminal-help/.zshrc ~/.zshrc
#
# Most people should NOT do that — they already have a ~/.zshrc worth keeping.
# The normal install adds one source line to the ~/.zshrc you already have,
# which is what ./install.sh does for you.
#
# Personal settings do not belong in this file: it is in git. Put them in
# user.sh, which is not. See user.sh.example.

source "${${(%):-%x}:A:h}/terminal-help.zsh"
