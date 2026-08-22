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
    eval "get_${name}_help() { th_page th_show_topic ${name} \"\$@\" }"
    th_info_twin "get_${name}_help"

    # Does this topic HAVE a detailed view? Read from the file rather than
    # declared in the header, because the answer is simply whether the body
    # contains a th_detail guard — and a header field asserting it separately
    # is one more thing that can disagree with the code. A topic that fits one
    # screen has no detail, and must not be offered a --detailed that shows
    # nothing new.
    if grep -q '^[[:space:]]*th_detail\b' "$file" 2>/dev/null; then
        eval "_th_has_detail_${name}() { : }"
    fi

    # Secondary functions the file wants listed in the index, indented.
    #
    # The line is  function | emoji | description, and slicing on `|` CANNOT
    # TELL A MISSING FIELD FROM A PRESENT ONE: with no pipe, ${also%%|*} and
    # ${also#*|} both return the whole string, so the function name became its
    # own emoji and its own description and the index rendered it three times.
    # Count the separators first, then fall back the same way a missing
    # TH_EMOJI/TH_DESC does above — and say so, naming the file, because
    # TH_ALSO is a documented extension point for user files and the person
    # who gets this wrong is writing their first one.
    for also in ${(f)"$(th_header_fields "$file" TH_ALSO)"}; do
        local fn=${${also%%|*}##[[:space:]]#}; fn=${fn%%[[:space:]]#}
        [[ -n $fn ]] || continue
        # Declared WITH the fallback values, never as a bare `local ae ad`:
        # zsh's `local` PRINTS a parameter that already exists, so on the
        # second TH_ALSO line of any file a bare declaration dumps `ae=…` into
        # every shell that starts. Asserted below, because no tier saw it.
        local rest=${also#*|} ae="📄" ad=$fn
        if [[ $also == *'|'*'|'* ]]; then
            ae=${${rest%%|*}##[[:space:]]#}; ae=${ae%%[[:space:]]#}
            ad=${${rest#*|}##[[:space:]]#}
        else
            th_warn "TH_ALSO in ${file:t}: '$also' has no | emoji | description"
            th_note "the format is:  # TH_ALSO:  $fn | 📄 | what it covers"
        fi
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
    local topic=$1 hook ran=0 arg
    shift

    # Two independent axes, not one enum: how much of THIS topic, and how much
    # of its neighbours. --all is not a third mode, it is both switches thrown,
    # which is why `--detailed --related` and `--all` are the same command.
    local view=summary related=named

    # An unknown flag is REPORTED, never swallowed. A tool that silently
    # ignores what you typed teaches you that it did what you asked.
    for arg in "$@"; do
        case $arg in
            --detailed|--detail|-d) view=detailed ;;
            --related|-r)           related=summary ;;
            --all|-a)               view=detailed; related=summary ;;
            --help|-h)              th_topic_usage "$topic"; return 0 ;;
            *)  th_warn "get_${topic}_help: I do not know the option '$arg'"
                th_note "try get_${topic}_help --help"
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

    # Dynamically scoped, exactly like the stack above, so th_detail can read it
    # from inside a hook without the hook being handed anything. A help file
    # writes `th_detail || return` and never mentions a variable.
    local _th_view=$view

    for hook in ${=TH_TOPIC_HOOKS[$topic]}; do
        th_defined "$hook" || continue
        $hook
        ran=1
    done
    (( ran )) || th_warn "no content is loaded for topic '$topic'"

    # Say the fuller view exists, and only when there IS one. Offering
    # --detailed on a topic that has no detail is a promise the tool cannot
    # keep, and the reader has no way to know which topics are which.
    if [[ $view == summary ]] && th_defined "_th_has_detail_$topic"; then
        # A blank line first, or the hint renders as a continuation of whatever
        # th_note happened to end the body — it is indented the same way, so it
        # reads as a caveat about the last command rather than about the topic.
        print -r --
        th_note "get_${topic}_help --detailed for the rest of it"
    fi

    th_show_related "$topic" "$related"
}

# Called from inside a help file, as a guard:
#
#     th_detail || return       # everything below is the detailed view
#
# A guard rather than a second hand-written body, and that choice is the whole
# design. Two bodies means every topic's content exists twice and the summary
# drifts from the detail the first time somebody edits one of them. One body
# with a cut line means the summary is BY CONSTRUCTION a prefix of the detail,
# so they cannot disagree — and adding the feature to twelve existing files was
# choosing twelve cut points, not re-authoring 700 lines of cheat-sheet.
#
# Returns true (0) in the detailed view, false in the summary view. Outside a
# topic — someone calling _th_help_git directly — it returns true, because a
# bare call should print everything rather than silently truncate.
th_detail() {
    [[ ${_th_view:-detailed} == detailed ]]
}

# What --help prints. One place, so twelve topics cannot describe the same four
# flags twelve slightly different ways.
th_topic_usage() {  # th_topic_usage <topic>
    local topic=$1
    local -a related
    related=(${=TH_TOPIC_RELATED[$topic]})

    th_head "${TH_TOPIC_EMOJI[$topic]:-📄}" "get_${topic}_help — the views"
    th_text "${TH_TOPIC_DESC[$topic]:-$topic help}"
    print -r --
    th_row "get_${topic}_help"             "a summary — never more than one screen"
    th_row "  --detailed"                  "all of $topic, paged like less"
    th_row "  --related"                   "the summary, plus a summary of each related topic"
    th_row "  --all"                       "all of $topic, plus a summary of each related topic"
    th_note "--all is exactly --detailed --related; the two spellings are one command"
    th_row "  --help"                      "this"
    print -r --
    if (( ${#related} )); then
        th_row "Related topics:" "${(j:, :)related}"
    else
        th_row "Related topics:" "none — $topic stands on its own"
    fi
    th_row "Also spelled:"  "get_${topic}_info, with any of the above"
    th_note "TH_NO_PAGER=1 turns paging off; TH_PAGER sets the command"
}

# A related topic is NAMED by default and printed only under --all.
#
# It used to be printed unconditionally, and one call site made the case on its
# own: `_th_help_mac` ended by calling get_homebrew_help, so at 100 columns
# get_mac_help was 132 lines of which 69 were Homebrew and 21 were macOS. Asking
# for macOS help and getting mostly a package manager is not help, and there was
# no way to say no. Naming it costs four lines and loses nothing, because the
# name IS the command.
th_show_related() {  # th_show_related <topic> named|summary
    local topic=$1 mode=$2 r
    local -a related
    related=(${=TH_TOPIC_RELATED[$topic]})
    (( ${#related} )) || return 0

    if [[ $mode == summary ]]; then
        for r in $related; do
            # Already on the stack: printing it again would be a duplicate at
            # best, so skip it quietly rather than letting th_show_topic's
            # guard shout at somebody who did nothing wrong.
            #
            # What this actually catches is a topic that lists ITSELF in
            # TH_RELATED. It is NOT what makes a mutual pair (python names
            # pytest, pytest names python) quiet — expansion is one level, so
            # the nested call never expands its own related topics and the pair
            # cannot re-enter in the first place. That distinction was got
            # wrong in the comment here for one release: the belief was that
            # this line held the mutual case, and a plant proved otherwise by
            # removing it and watching every test still pass. The reachable
            # case is `# TH_RELATED: <its own name>`, which without this line
            # prints the re-entrancy warning during ordinary use.
            (( ${_th_topic_stack[(I)$r]} )) && continue
            th_defined "get_${r}_help" || continue
            # SUMMARY, and no further expansion. One level out, deliberately:
            # a neighbour's neighbours are not what was asked for, and letting
            # it recurse turns "and what else should I know" into the whole
            # manual — which is the complaint that started all of this.
            th_show_topic "$r"
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
    th_note "get_${topic}_help --related summarises these here as well"
}

# --- paging -----------------------------------------------------------------
# The detailed view runs to several pages, and a cheat-sheet that scrolls off
# the top is one you cannot read. So page it — but ONLY when there is a person
# and a terminal on the other end.
#
# Three things this must not break, all of them promises the README already
# makes:
#
#   get_git_help > notes.txt     must be plain text, unpaged
#   get_git_help | grep push     must not hang waiting for a pager
#   a one-screen summary         must not be worth a pager at all
#
# The [[ -t 1 ]] test covers the first two. The height comparison covers the
# third: paging output that already fits is how a tool earns a TH_NO_PAGER=1
# in everybody's rc file.
th_page() {  # th_page <command> [args...]
    if [[ -n $TH_NO_PAGER || ! -t 1 ]]; then
        "$@"
        return
    fi

    local out rc
    # TH_FORCE_COLOR because capturing makes stdout a pipe, and th_use_color
    # would otherwise strip every escape from output that IS going to a
    # terminal, just via less. See th_use_color.
    out=$(TH_FORCE_COLOR=1 "$@"); rc=$?

    local -a lines=("${(@f)out}")
    if (( ${#lines} < $(th_rows) )); then
        print -r -- "$out"
        return $rc
    fi

    # -R  keep the colour we just forced
    # -F  quit immediately if it turns out to fit after all
    # -X  do NOT clear the screen on exit, so what you read stays in scrollback.
    #     A help screen that vanishes when you press q is worse than no pager:
    #     you page through it to find the command, quit, and it is gone.
    print -r -- "$out" | ${=TH_PAGER:-less -R -F -X}
    return $rc
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
