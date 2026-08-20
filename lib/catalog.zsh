#!/usr/bin/env zsh
# 📋 get_help_topics — every help command that exists right now, plus how to
# drive terminal-help itself.
#
# get_help is the curated index: topics, in a deliberate order, with their
# sub-sections. This is the flat, complete, discovered-at-runtime list — every
# get_*_help function actually defined in THIS shell, whether it came from the
# package, from a file you dropped in, or from an extension. If you can call
# it, it is in here.

get_help_topics() {
    th_head "📋" "Every help command"

    # Discovered, not listed by hand: a hardcoded list is wrong the moment
    # somebody drops a file in ~/.zshrc-help.d, which is the whole point.
    local -a all
    all=(${${(f)"$(whence -wm 'get_*_help' 2>/dev/null)"}%%:*})
    all=(${(o)${all:#}})

    if (( ! ${#all} )); then
        th_warn "no help commands are defined — is terminal-help loaded?"
        th_row "Check:" "th_doctor"
        return 1
    fi

    # Which topic does a command belong to, and did it come from the user?
    local -A owner
    local topic fn
    for topic in ${TH_TOPIC_ORDER}; do
        owner[get_${topic}_help]=$topic
        for fn in ${TH_ALSO_ORDER}; do
            [[ ${TH_ALSO_PARENT[$fn]} == $topic ]] && owner[$fn]=$topic
        done
    done

    local -a package_cmds user_cmds
    for fn in ${all}; do
        topic=${owner[$fn]:-}
        if [[ -n $topic && ${TH_TOPIC_CATEGORY[$topic]} == user ]]; then
            user_cmds+=("$fn")
        else
            package_cmds+=("$fn")
        fi
    done

    th_sub "📦" "From terminal-help (${#package_cmds})"
    for fn in ${package_cmds}; do
        topic=${owner[$fn]:-}
        if [[ -n ${TH_ALSO_DESC[$fn]} ]]; then
            th_row "$fn" "${TH_ALSO_DESC[$fn]}"
        elif [[ -n $topic ]]; then
            th_row "$fn" "${TH_TOPIC_EMOJI[$topic]} ${TH_TOPIC_DESC[$topic]}"
            [[ -n ${TH_TOPIC_EXTENDED[$topic]} ]] && th_note "extended by one of your own files"
        else
            th_row "$fn" "—"
        fi
    done

    if (( ${#user_cmds} )); then
        th_sub "🧩" "Yours (${#user_cmds})"
        for fn in ${user_cmds}; do
            topic=${owner[$fn]:-}
            th_row "$fn" "${TH_TOPIC_EMOJI[$topic]} ${TH_TOPIC_DESC[$topic]}"
        done
    fi

    # Installed but not selected: a command you cannot call yet, which is worth
    # naming rather than leaving out of a list that claims to be complete.
    local -a idle
    local t
    for t in ${(f)"$(th_available_topics)"}; do
        (( ${TH_TOPIC_ORDER[(I)$t]} )) || idle+=("get_${t}_help")
    done
    if (( ${#idle} )); then
        th_sub "⬜" "Installed but switched off (${#idle})"
        for fn in ${(o)idle}; do
            th_row "$fn" "th_topics enable ${${fn#get_}%_help}"
        done
    fi

    get_terminal_help_usage
}

# The generic "how do I drive this thing" half.
get_terminal_help_usage() {
    th_sub "🧰" "Using terminal-help"
    th_row "get_help"        "the curated index — topics in order, with sub-sections"
    th_row "get_help_topics" "this: every command that exists, flat and discovered"
    th_row "th_topics"       "what is on, what is off, and turn things on or off"
    th_row "th_doctor"       "why isn't my help — or my settings file — loading?"
    th_row "get_versions"    "what is installed on this machine"
    th_note "help_me is an alias for get_help, if that is what your fingers do"

    th_sub "📁" "Where things live"
    th_row "~/.zshrc"           "one marked block; the installer rewrites it"
    th_row "~/.zshrc-user.sh"   "YOURS: aliases, exports, PATH. Never touched."
    th_row "~/.zshrc-help.d/"   "YOURS: help you write. Never touched."
    th_row "~/.terminal-help/"  "the runtime — replaced on upgrade"
    th_note "~/.terminal-help/help/user is a symlink to ~/.zshrc-help.d, so"
    th_note "your files are reachable from inside the tree but never inside"
    th_note "anything the installer deletes"

    th_sub "✍️" "Adding your own"
    th_text "A topic of your own — any *.help.sh under ~/.zshrc-help.d, at any"
    th_text "depth, with a three-line header:"
    th_row "  " "# TH_TOPIC: deploy"
    th_row "  " "# TH_EMOJI: 🚀"
    th_row "  " "# TH_DESC:  our deploy runbook"
    th_row "  " "_th_help_deploy() { th_head \"🚀\" \"Deploy\"; th_row \"Staging:\" \"...\" }"
    th_note "get_deploy_help is generated from that header — you never write it"
    print -r --
    th_text "An extension — add to a topic that ships with terminal-help,"
    th_text "without editing the package file:"
    th_row "  " "# ~/.zshrc-help.d/extensions/git.help.sh"
    th_row "  " "_th_ext_git_mine() { th_sub \"🔧\" \"Mine\"; th_row \"Fixup:\" \"...\" }"
    th_row "  " "th_extend git _th_ext_git_mine"
    th_note "get_git_help then prints the built-in content and then yours, so"
    th_note "an upgrade cannot overwrite it and it cannot go stale against a"
    th_note "package file you copied"
    print -r --
    th_row "Helpers you can use:" "th_head  th_sub  th_row  th_note  th_text  th_warn  th_ok"

    th_sub "⬆️" "Installing and upgrading"
    th_row "Upgrade:"    "cd <clone> && git pull && ./install.sh --yes"
    th_note "re-running is the upgrade: it re-copies the runtime and rewrites"
    th_note "its own block, and touches neither of your two directories"
    th_row "Change topics:" "th_topics enable <topic>    (no clone needed)"
    th_row "Contribute back:" "scripts/promote-extensions.sh    (in the clone)"
    th_row "Remove it:"  "./install.sh --uninstall"
    th_note "that removes the block and the runtime, and leaves your files"
}
