#!/usr/bin/env zsh
# 📋 versions — what is actually installed on this machine.

get_versions() {
    th_head "📋" "Versions"
    local os
    case "$OSTYPE" in
        darwin*)  os="macOS $(sw_vers -productVersion 2>/dev/null) ($(uname -m))" ;;
        linux*)   os="$( [[ -r /etc/os-release ]] && . /etc/os-release && print -r -- "$PRETTY_NAME" || uname -sr ) ($(uname -m))" ;;
        msys*|cygwin*) os="Windows ($(uname -s))" ;;
        *)        os="$(uname -sr)" ;;
    esac
    [[ -n $WSL_DISTRO_NAME ]] && os="$os · WSL $WSL_DISTRO_NAME"

    th_row "terminal-help:"      "v${TH_VERSION:-unknown}"
    th_row "OS:"                 "$os"
    th_row "Shell:"              "zsh $ZSH_VERSION"
    th_row "Python:"             "$(python3 --version 2>/dev/null || print 'not installed')"
    th_row "uv:"                 "$(uv --version 2>/dev/null || print 'not installed')"
    th_row "git:"                "$(git --version 2>/dev/null || print 'not installed')"
    th_row "gh:"                 "$(gh --version 2>/dev/null | head -n 1 || print 'not installed')"
    th_row "node:"               "$(node --version 2>/dev/null || print 'not installed')"
    if command -v brew >/dev/null 2>&1; then
        th_row "brew:"           "$(brew --version 2>/dev/null | head -n 1)"
    fi
    th_row "uvicorn:"            "$(uv run uvicorn --version 2>/dev/null || print 'not installed in this project')"
    th_note "uvicorn is per-project — this reads the venv of the current directory"
}
