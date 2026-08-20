#!/usr/bin/env zsh
# ❓ help — the index. Everything else is one command away from here.

th_register get_help "❓ this list"

get_help() {
    th_head "🧰" "terminal-help v${TH_VERSION:-unknown}"
    th_text "A reference that lives in the shell. Every section is a function;"
    th_text "type its name to print it."
    print -r --

    # Built from the registry, in the order the files were loaded — so a new
    # help file appears here by existing, with no index to edit.
    local i fn desc level last_level=0
    for (( i = 1; i <= ${#TH_REG_FN}; i++ )); do
        fn=${TH_REG_FN[i]}; desc=${TH_REG_DESC[i]}; level=${TH_REG_LEVEL[i]}
        th_defined "$fn" || continue
        [[ -n ${TH_USER_HELP_FN[(r)$fn]} ]] && continue   # listed under 🧩 instead
        (( level == 0 && last_level == 1 )) && print -r --
        if (( level )); then th_row "  $fn" "$desc"; else th_row "$fn" "$desc"; fi
        last_level=$level
    done

    get_user_help_sections
    print -r --
    get_user_help
}

# Sections that came from the user's own help directory. Listed separately
# because "what I added" is the thing a person scans for, and because a file
# that forgot to call th_register still has to appear somewhere.
get_user_help_sections() {
    (( ${#TH_USER_HELP_FN} )) || return 0
    th_sub "🧩" "Yours (from ${TH_USER_HELP_DIR/#$HOME/~})"
    local fn i desc
    for fn in ${TH_USER_HELP_FN}; do
        desc=""
        for (( i = 1; i <= ${#TH_REG_FN}; i++ )); do
            [[ ${TH_REG_FN[i]} == "$fn" ]] && { desc=${TH_REG_DESC[i]}; break }
        done
        th_row "$fn" "${desc:-📄 ${TH_USER_HELP_SRC[$fn]:-your own section}}"
    done
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

    local file="${TH_USER_FILE:-${ZDOTDIR:-$HOME}/.zshrc-user.sh}"
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
