#!/usr/bin/env zsh
# ❓ help — the index. Everything else is one command away from here.

get_help() {
    th_head "🧰" "terminal-help v${TH_VERSION:-unknown}"
    th_text "A reference that lives in the shell. Every section is a function;"
    th_text "type its name to print it."
    print -r --
    th_row "get_help"            "❓ this list"
    th_row "get_versions"        "📋 what is installed on this machine"
    print -r --
    th_row "get_git_info"        "🌿 git — all three sections below"
    th_row "  get_git_branch_info"   "🌱 branch naming and commit messages"
    th_row "  get_git_worktree_info" "🌳 worktrees, and the rules that make them work"
    th_row "  get_git_pr_info"       "🔀 pull requests with gh"
    print -r --
    th_row "get_python_info"     "🐍 Python — with the two below"
    th_row "  get_uv_info"       "📦 uv: projects, dependencies, venvs"
    th_row "  get_uvicorn_info"  "⚡ uvicorn and FastAPI launch lines"
    print -r --
    th_row "get_mac_info"        "🍎 macOS: brew, shares, Finder"
    th_row "get_linux_info"      "🐧 Linux: installing zsh, packages, services"
    th_row "get_windows_info"    "🪟 Windows: PowerShell, winget, WSL, zsh"
    print -r --
    get_user_help
}

# The private half. What appears here depends on what user.sh actually
# DEFINES — not on whether the file exists, since install.sh always creates it
# and creates it empty.
get_user_help() {
    if [[ -z $TH_USER_SOURCED ]]; then
        th_sub "🔒" "Yours (not loaded)"
        th_text "terminal-help is loaded but your settings file is not — nothing"
        th_text "called th_source_user. Add it to your ~/.zshrc after the source"
        th_text "line, or re-run the installer."
        th_row "Your settings file:" "${TH_USER_FILE:-${ZDOTDIR:-$HOME}/.zshrc-user.sh}"
        th_row "Load it now:"        "th_source_user"
        return
    fi

    local -a defined
    th_defined get_user_info && defined+=("get_user_info|🔒 your own reference sections")

    if (( ${#defined} )) || th_defined user_on_load || [[ -s $file ]]; then
        th_sub "🔒" "Yours (from ${file:t}, never committed)"
        local entry
        for entry in "${defined[@]}"; do
            th_row "${entry%%|*}" "${entry#*|}"
        done
        # A file holding only aliases and exports defines no hooks, and that is
        # a perfectly good use of it — say so rather than calling it empty.
        (( ${#defined} )) || th_row "${file:t}" "loaded — no hooks defined, which is fine"
        th_defined user_on_load && th_note "user_on_load runs on every new shell"
    else
        th_sub "🔒" "Yours (empty for now)"
        th_text "Aliases, exports, PATH entries, your own reference sections —"
        th_text "they go in your settings file, not in ~/.zshrc. It is loaded on"
        th_text "every shell, and a terminal-help upgrade never touches it."
        th_row "Your settings file:" "${TH_USER_FILE:-${ZDOTDIR:-$HOME}/.zshrc-user.sh}"
        th_row "What can go in it:"  "cat \"${TH_HOME:-.}/zshrc-user.sh.example\""
    fi
}

# The one line printed when a shell starts.
th_banner() {
    th_load_colors
    print -r -- "${TH_C_bold}${TH_C_title}🧰 terminal-help${TH_C_reset} ${TH_C_bold}v${TH_VERSION:-unknown}${TH_C_reset}${TH_C_note} · ${TH_C_reset}${TH_C_cmd}get_help${TH_C_reset}"
}
