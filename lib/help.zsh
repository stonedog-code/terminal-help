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

# The private half. What appears here depends entirely on what user.sh
# defines — the checked-in code knows the hook names and nothing else.
get_user_help() {
    if [[ -n $TH_USER_LOADED ]]; then
        th_sub "🔒" "Yours (from user.sh, never committed)"
        th_defined get_user_info   && th_row "get_user_info"   "🔒 your own reference sections"
        th_defined connect_work    && th_row "connect_work"    "🔌 mount your work share"
        th_defined disconnect_work && th_row "disconnect_work" "🔌 unmount it"
        th_defined user_on_load    && th_note "user_on_load runs on every new shell"
    else
        th_sub "🔒" "Yours (not set up yet)"
        th_text "Private commands — a work share to mount, your own aliases,"
        th_text "your own reference sections — live in user.sh, which is"
        th_text "gitignored and never leaves this machine."
        th_row "Start it:"       "cp \"${TH_HOME:-.}/user.sh.example\" \"${TH_USER_FILE:-${TH_HOME:-.}/user.sh}\""
    fi
}

# The one line printed when a shell starts.
th_banner() {
    th_load_colors
    print -r -- "${TH_C_bold}${TH_C_title}🧰 terminal-help${TH_C_reset} ${TH_C_bold}v${TH_VERSION:-unknown}${TH_C_reset}${TH_C_note} · ${TH_C_reset}${TH_C_cmd}get_help${TH_C_reset}"
}
