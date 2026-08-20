#!/usr/bin/env zsh
# ❓ help — the index. Everything else is one command away from here.

get_help() {
    th_head "🧰" "terminal-help v${TH_VERSION:-unknown}"
    th_text "A reference that lives in the shell. Every topic is a command;"
    th_text "type its name to print it."
    print -r --

    th_row "get_help"        "❓ this list"
    th_row "get_help_topics" "📋 every help command, and how to drive this tool"
    th_row "get_versions"    "🖥  what is installed on this machine"
    th_row "th_topics"       "🗂 turn help topics on and off"
    th_row "th_doctor"       "🩺 why isn't my help or my settings file loading?"
    print -r --

    local topic fn
    for topic in ${TH_TOPIC_ORDER}; do
        [[ ${TH_TOPIC_CATEGORY[$topic]} == user ]] && continue
        th_row "get_${topic}_help" "${TH_TOPIC_EMOJI[$topic]} ${TH_TOPIC_DESC[$topic]}"
        [[ -n ${TH_TOPIC_EXTENDED[$topic]} ]] && th_note "extended by one of your own files"
        for fn in ${TH_ALSO_ORDER}; do
            [[ ${TH_ALSO_PARENT[$fn]} == $topic ]] && th_defined "$fn" && th_row "  $fn" "${TH_ALSO_DESC[$fn]}"
        done
    done

    # Topics that are installed but not selected. Saying so beats a list that
    # quietly omits them, which reads as "terminal-help has no macOS help".
    local -a idle
    local t
    for t in ${(f)"$(th_available_topics)"}; do
        (( ${TH_TOPIC_ORDER[(I)$t]} )) || idle+=("$t")
    done
    if (( ${#idle} )); then
        print -r --
        th_row "$(( ${#idle} )) more installed:" "${(j:, :)${(o)idle}}"
        th_note "turn one on with: th_topics enable <topic>"
    fi

    _th_user_topics_section
    print -r --
    _th_user_settings_section
}

# Topics that came from the user's own help directory.
_th_user_topics_section() {
    local -a mine
    local topic
    for topic in ${TH_TOPIC_ORDER}; do
        [[ ${TH_TOPIC_CATEGORY[$topic]} == user ]] && mine+=("$topic")
    done
    (( ${#mine} )) || return 0
    th_sub "🧩" "Yours (from ${TH_USER_HELP_DIR/#$HOME/~})"
    for topic in ${mine}; do
        th_row "get_${topic}_help" "${TH_TOPIC_EMOJI[$topic]} ${TH_TOPIC_DESC[$topic]}"
    done
}

# The private half. What appears here depends on what user.sh actually
# DEFINES — not on whether the file exists, since install.sh always creates it
# and creates it empty.
_th_user_settings_section() {
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
        th_row "What can go in it:"  "head -30 \"$file\""
        th_note "its own header comments say what it can hold"
    fi
}

# The one line printed when a shell starts.
th_banner() {
    th_load_colors
    print -r -- "${TH_C_bold}${TH_C_title}🧰 terminal-help${TH_C_reset} ${TH_C_bold}v${TH_VERSION:-unknown}${TH_C_reset}${TH_C_note} · ${TH_C_reset}${TH_C_cmd}get_help${TH_C_reset}"
}
