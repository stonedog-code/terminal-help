#!/usr/bin/env zsh
# topics.zsh — the catalogue: what a help file is, how one is discovered,
# selected, loaded and extended.
#
# A help file declares itself in a HEADER COMMENT, and that header is the only
# metadata anywhere:
#
#     # TH_TOPIC: git
#     # TH_EMOJI: 🌿
#     # TH_DESC:  git — branches, worktrees, pull requests
#     # TH_ALSO:  get_git_worktree_help | 🌳 | worktrees, and the rules
#
#     _th_help_git() { ... }
#
# A comment rather than a shell call, because install.sh (bash) has to read the
# same facts to build its menu, and a bash script that greps shell code is
# coupled to how that code is formatted. One fixed line each, greppable by
# anything, executable by nothing.
#
# The entry point `get_git_help` is GENERATED from the header. That is what
# makes extensions work: the generated function walks a hook list, so a user
# file can append to a topic it does not own and did not modify.

typeset -gA TH_TOPIC_EMOJI TH_TOPIC_DESC TH_TOPIC_FILE TH_TOPIC_HOOKS TH_TOPIC_CATEGORY
typeset -ga TH_TOPIC_ORDER
typeset -gA TH_ALSO_DESC
typeset -ga TH_ALSO_ORDER
typeset -gA TH_ALSO_PARENT

# Read one header field without sourcing the file. Only the first 20 lines are
# examined: a header is a header, not something buried mid-file.
th_header_field() {  # th_header_field <file> <FIELD>
    setopt localoptions extended_glob
    local line
    while IFS= read -r line; do
        [[ $line == "# $2:"* ]] || continue
        line=${line#"# $2:"}
        print -r -- "${line##[[:space:]]#}"
        return 0
    done < <(head -n 20 -- "$1" 2>/dev/null)
    return 1
}

th_header_fields() {  # every value of a repeatable field, one per line
    setopt localoptions extended_glob
    local line
    while IFS= read -r line; do
        [[ $line == "# $2:"* ]] || continue
        line=${line#"# $2:"}
        print -r -- "${line##[[:space:]]#}"
    done < <(head -n 20 -- "$1" 2>/dev/null)
}

# Register a topic from its file, then generate its entry point.
th_load_topic_file() {  # th_load_topic_file <file> [category]
    setopt localoptions extended_glob
    local file=$1 category=${2:-} name emoji desc also
    name=$(th_header_field "$file" TH_TOPIC) || return 1
    [[ $name == [a-z0-9_]## ]] || { th_warn "skipping ${file:t}: topic '$name' is not [a-z0-9_]"; return 1 }

    emoji=$(th_header_field "$file" TH_EMOJI) || emoji="📄"
    desc=$(th_header_field "$file" TH_DESC)   || desc="${name} help"

    if [[ -z ${TH_TOPIC_EMOJI[$name]+set} ]]; then
        TH_TOPIC_ORDER+=("$name")
        TH_TOPIC_HOOKS[$name]=""
    fi
    TH_TOPIC_EMOJI[$name]=$emoji
    TH_TOPIC_DESC[$name]=$desc
    TH_TOPIC_FILE[$name]=$file
    TH_TOPIC_CATEGORY[$name]=${category:-${${file:h}:t}}

    source "$file"

    # The topic's own body is the first hook; extensions append after it.
    if th_defined "_th_help_$name"; then
        TH_TOPIC_HOOKS[$name]="_th_help_$name ${TH_TOPIC_HOOKS[$name]}"
    fi

    # Generated entry point. The name is validated above, so this eval expands
    # nothing a help file controls beyond [a-z0-9_].
    eval "get_${name}_help() { th_show_topic ${name} }"

    # Secondary functions the file wants listed in the index, indented.
    for also in ${(f)"$(th_header_fields "$file" TH_ALSO)"}; do
        local fn=${${also%%|*}##[[:space:]]#}; fn=${fn%%[[:space:]]#}
        local rest=${also#*|}
        local ae=${${rest%%|*}##[[:space:]]#}; ae=${ae%%[[:space:]]#}
        local ad=${${rest#*|}##[[:space:]]#}
        [[ -n $fn ]] || continue
        if [[ -z ${TH_ALSO_DESC[$fn]+set} ]]; then TH_ALSO_ORDER+=("$fn"); fi
        TH_ALSO_DESC[$fn]="$ae $ad"
        TH_ALSO_PARENT[$fn]=$name
    done
}

# Run a topic: its own body, then every extension registered for it, in the
# order they were registered. An explicit list rather than a naming convention
# scanned at runtime — the order is then a fact, not an accident of globbing.
th_show_topic() {
    local topic=$1 hook ran=0
    for hook in ${=TH_TOPIC_HOOKS[$topic]}; do
        th_defined "$hook" || continue
        $hook
        ran=1
    done
    (( ran )) || th_warn "no content is loaded for topic '$topic'"
}

# Called by a user's extension file: add to a topic you do not own.
th_extend() {  # th_extend <topic> <function>
    local topic=$1 fn=$2
    if [[ -z ${TH_TOPIC_HOOKS[$topic]+set} ]]; then
        # Extending something not installed is not an error worth shouting
        # about — the user may simply not have that topic selected today.
        TH_ORPHAN_EXTENSIONS+=("$topic")
        return 0
    fi
    TH_TOPIC_HOOKS[$topic]="${TH_TOPIC_HOOKS[$topic]} $fn"
    TH_TOPIC_EXTENDED[$topic]=1
}
typeset -ga TH_ORPHAN_EXTENSIONS
typeset -gA TH_TOPIC_EXTENDED

# --- selection -------------------------------------------------------------
# The manifest lists the topics that load. Everything ships to disk; this is
# what decides what runs, so re-selecting never needs the source clone again.
th_selected_topics() {
    local manifest="${TH_SELECTED:-$TH_HOME/selected}"
    [[ -r $manifest ]] || return 0     # no manifest: the caller loads everything
    local -a lines
    lines=(${(f)"$(<$manifest)"})
    lines=(${lines:#\#*})              # drop comment lines
    lines=(${lines:#})                 # drop blanks
    print -rl -- $lines
}

th_available_topics() {
    local f
    for f in "$TH_HOME"/help/*/*.help.sh(N); do
        [[ ${${f:h}:t} == user ]] && continue
        th_header_field "$f" TH_TOPIC
    done
}

# `th_topics` — see what exists, turn things on and off, with no clone needed.
th_topics() {
    local manifest="${TH_SELECTED:-$TH_HOME/selected}"
    local action=${1:-list} topic=$2
    local -a selected available
    selected=(${(f)"$(th_selected_topics)"})
    available=(${(f)"$(th_available_topics)"})

    case $action in
        list)
            th_head "🗂" "Help topics"
            th_text "Selected topics load in every shell. The rest are installed"
            th_text "but idle — turning one on costs nothing but a new shell."
            print -r --
            local t
            for t in ${(o)available}; do
                if (( ${selected[(I)$t]} )); then
                    th_row "  ✅ $t" "${TH_TOPIC_DESC[$t]:-}"
                else
                    th_row "  ⬜ $t" "$(th_header_field "$TH_HOME/help/"*/"$t.help.sh"(N[1]) TH_DESC)"
                fi
            done
            print -r --
            th_row "Turn one on:"  "th_topics enable <topic>"
            th_row "Turn one off:" "th_topics disable <topic>"
            th_row "Everything:"   "th_topics all"
            ;;
        enable|disable|all)
            local -a next
            case $action in
                all)     next=($available) ;;
                enable)  next=($selected $topic) ;;
                disable) next=(${selected:#$topic}) ;;
            esac
            next=(${(u)next})
            print -rl -- "# terminal-help topics — one per line. th_topics to change." $next > $manifest
            th_ok "saved ${#next} topic(s) to ${manifest/#$HOME/~}"
            th_note "open a new shell to load the change"
            ;;
        *)  th_warn "usage: th_topics [list|enable <topic>|disable <topic>|all]" ;;
    esac
}
