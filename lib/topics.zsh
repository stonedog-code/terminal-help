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
#     # TH_RELATED: github
#
# TH_ALSO and TH_RELATED are different relationships and are treated
# differently. TH_ALSO is a sub-section of THIS topic, living in this file: it
# prints as part of the topic, because it is part of the topic. TH_RELATED
# names a SEPARATE topic — its own file, its own entry in `selected`, its own
# `th_topics enable` — and is only NAMED by default. `--all` prints it too.
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
typeset -gA TH_TOPIC_RELATED
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

# Every command answers to two names: `_help` and `_info`. People reach for
# whichever word they think in, and being wrong about which one this tool chose
# is a `command not found` for something that is right there.
#
# A generated FUNCTION, never an alias. Measured in zsh: an alias defined and
# used in the same parse unit is not expanded — `alias get_mac_info=get_mac_help`
# then calling it fails with `command not found` — so it would not work from a
# script, or from inside another function, which is most of the ways one command
# reaches another here. Aliases are also invisible to the `whence -w` discovery
# get_help_topics is built on.
#
# Underscores, not dashes. `get-mac-help` is a perfectly valid zsh function
# name, so this is taste rather than capability: the rest of the tool is
# underscore-idiomatic (get_help, get_versions, th_doctor), a dashed name reads
# like an external binary in `which` output, and a second separator on top of
# the twin would mean four names per topic for get_help_topics to render.
th_info_twin() {  # th_info_twin <get_x_help>  ->  defines get_x_info
    local fn=$1
    setopt localoptions extended_glob
    # The name reaches here from a TH_ALSO header in a file this tool did not
    # write, and it is about to be eval'd. Validate before, not after.
    if [[ $fn != get_[a-z0-9_]##_help ]]; then
        th_warn "cannot make an _info twin for '$fn'"
        th_note "the name must look like get_<something>_help, lowercase"
        return 1
    fi
    eval "${fn%_help}_info() { $fn \"\$@\" }"
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

    # Repeatable, so a topic can point at more than one. Validated to the same
    # [a-z0-9_] a topic name is, because these are looked up and printed.
    local -a rel
    for also in ${(f)"$(th_header_fields "$file" TH_RELATED)"}; do
        if [[ $also == [a-z0-9_]## ]]; then
            rel+=("$also")
        else
            th_warn "skipping TH_RELATED '$also' in ${file:t}: not a topic name"
        fi
    done
    TH_TOPIC_RELATED[$name]="${rel}"

    source "$file"

    # The topic's own body is the first hook; extensions append after it.
    if th_defined "_th_help_$name"; then
        TH_TOPIC_HOOKS[$name]="_th_help_$name ${TH_TOPIC_HOOKS[$name]}"
    fi

    # Generated entry point. The name is validated above, so this eval expands
    # nothing a help file controls beyond [a-z0-9_].
    eval "get_${name}_help() { th_show_topic ${name} \"\$@\" }"
    th_info_twin "get_${name}_help"

    # Secondary functions the file wants listed in the index, indented.
    for also in ${(f)"$(th_header_fields "$file" TH_ALSO)"}; do
        local fn=${${also%%|*}##[[:space:]]#}; fn=${fn%%[[:space:]]#}
        local rest=${also#*|}
        local ae=${${rest%%|*}##[[:space:]]#}; ae=${ae%%[[:space:]]#}
        local ad=${${rest#*|}##[[:space:]]#}
        [[ -n $fn ]] || continue
        # Sub-sections are commands too, so they get the twin as well. This is
        # also the first thing to eval a name out of a TH_ALSO header, which is
        # why th_info_twin validates rather than trusting the file.
        th_info_twin "$fn"
        if [[ -z ${TH_ALSO_DESC[$fn]+set} ]]; then TH_ALSO_ORDER+=("$fn"); fi
        TH_ALSO_DESC[$fn]="$ae $ad"
        TH_ALSO_PARENT[$fn]=$name
    done
}

# Which topics are mid-print, innermost last. Declared global so the test below
# has something to index into on the OUTERMOST call; every nested call shadows
# it with a `local` of the same name.
typeset -ga _th_topic_stack

# Run a topic: its own body, then every extension registered for it, in the
# order they were registered. An explicit list rather than a naming convention
# scanned at runtime — the order is then a fact, not an accident of globbing.
#
# THE GUARD. A hook that re-enters its own topic loops until Ctrl-C, and it
# takes exactly one line in a user file to arrange:
#
#     th_extend git get_git_help
#
# Measured on the unguarded code: 44,495 lines in 8 seconds, ended only by
# `timeout`. th_extend now refuses that literal form, but refusing one spelling
# of a mistake is not the same as being unable to make it — an indirection
# through a wrapper, or a TH_RELATED cycle, arrives at the same place. So the
# loop is closed here, where every route has to pass.
#
# `local -a` is the whole mechanism, and it is doing two jobs. zsh scopes
# locals DYNAMICALLY, so a nested th_show_topic sees this array; and the shell
# restores it when the function exits by ANY route — return, error, or a
# Ctrl-C unwinding the stack. A global map with explicit cleanup would leak on
# that last one and leave the topic permanently refusing to print, which is a
# worse bug than the one being fixed.
th_show_topic() {
    local topic=$1 hook ran=0 all=0 arg
    shift

    # An unknown flag is REPORTED, never swallowed. A tool that silently
    # ignores what you typed teaches you that it did what you asked.
    for arg in "$@"; do
        case $arg in
            --all|-a) all=1 ;;
            *)  th_warn "get_${topic}_help: I do not know the option '$arg'"
                th_note "the only one is --all, which prints the related topics too"
                return 2 ;;
        esac
    done

    if (( ${_th_topic_stack[(I)$topic]} )); then
        th_warn "'$topic' is already printing — refusing to re-enter it"
        th_note "something inside topic '$topic' calls get_${topic}_help;"
        th_note "the chain was: ${(j: → :)_th_topic_stack} → $topic"
        return 1
    fi
    local -a _th_topic_stack=($_th_topic_stack $topic)

    for hook in ${=TH_TOPIC_HOOKS[$topic]}; do
        th_defined "$hook" || continue
        $hook
        ran=1
    done
    (( ran )) || th_warn "no content is loaded for topic '$topic'"

    th_show_related "$topic" $all
}

# A related topic is NAMED by default and printed only under --all.
#
# It used to be printed unconditionally, and one call site made the case on its
# own: `_th_help_mac` ended by calling get_homebrew_help, so at 100 columns
# get_mac_help was 132 lines of which 69 were Homebrew and 21 were macOS. Asking
# for macOS help and getting mostly a package manager is not help, and there was
# no way to say no. Naming it costs four lines and loses nothing, because the
# name IS the command.
th_show_related() {  # th_show_related <topic> <all?>
    local topic=$1 all=$2 r
    local -a related
    related=(${=TH_TOPIC_RELATED[$topic]})
    (( ${#related} )) || return 0

    if (( all )); then
        for r in $related; do
            # Already on the stack: it is printing further up the chain, so
            # printing it again would be a duplicate at best. A cycle in
            # TH_RELATED is a reasonable thing to write — two topics that each
            # point at the other — so this is a skip, not a complaint. The loud
            # warning in th_show_topic stays for the pathological case, a hook
            # that re-enters its OWN topic.
            (( ${_th_topic_stack[(I)$r]} )) && continue
            th_defined "get_${r}_help" || continue
            th_show_topic "$r" --all
        done
        return 0
    fi

    th_sub "🔗" "Related topics"
    for r in $related; do
        if th_defined "get_${r}_help"; then
            th_row "get_${r}_help" "${TH_TOPIC_EMOJI[$r]} ${TH_TOPIC_DESC[$r]}"
        else
            # Saying "installed but switched off" beats omitting it, which
            # reads as though the relationship does not exist.
            th_row "get_${r}_help" "not loaded — th_topics enable $r"
        fi
    done
    th_note "get_${topic}_help --all prints these here as well"
}

# Called by a user's extension file: add to a topic you do not own.
th_extend() {  # th_extend <topic> <function>
    local topic=$1 fn=$2

    # Registering a topic's own entry point as one of its hooks is an infinite
    # loop, and an easy one to write by accident: `get_git_help` is the name
    # you have been typing all along, so it is the name that comes to hand.
    # th_show_topic would catch it, but catching it there costs a shell full of
    # output and a warning about a chain the reader has to work backwards from.
    # Said here, it names the file and the line while they are still in view.
    if [[ $fn == "get_${topic}_help" ]]; then
        th_warn "th_extend $topic $fn would make the topic print itself forever"
        th_note "extend it with a function of YOUR own — get_${topic}_help is"
        th_note "the entry point that runs the hooks, not one of the hooks"
        return 1
    fi

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
