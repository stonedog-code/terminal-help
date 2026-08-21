#!/usr/bin/env zsh
# ui.zsh — colour, emoji and layout helpers. Every other lib/*.zsh is written
# in terms of these, so restyling the whole thing is one edit.

# Colour is on when the output is a terminal and nobody asked for it off.
# Decided per call rather than once at load: `get_git_info | less` should not
# be full of escape codes just because the shell that sourced this had a tty.
th_use_color() {
    [[ -n $TH_NO_COLOR || -n $NO_COLOR ]] && return 1
    [[ $TERM == (dumb|) ]] && return 1
    # The pager has to MEASURE the output before deciding whether to page it,
    # and measuring means capturing, and capturing makes stdout a pipe — so the
    # tty test below goes false and every colour silently comes back empty.
    # That looks exactly like a working monochrome theme, which is the same
    # trap th_load_colors already documents one level down. th_page sets this
    # only when the REAL stdout it inherited was a terminal.
    [[ -n $TH_FORCE_COLOR ]] && return 0
    [[ -t 1 ]]
}

# Is a function defined? Uses the `functions` builtin rather than
# $+functions[...], which needs the zsh/parameter module to be loadable.
th_defined() { functions "$1" >/dev/null 2>&1 }

# 256-colour palette, one place.
typeset -gA TH_PALETTE=(
    title   $'\e[38;5;39m'     # blue    — section titles
    label   $'\e[38;5;252m'    # near-white — the left column
    cmd     $'\e[38;5;222m'    # amber   — the thing you type
    note    $'\e[38;5;244m'    # grey    — the caveat
    rule    $'\e[38;5;238m'    # dark    — the underline
    sub     $'\e[38;5;150m'    # green   — sub-headings
    warn    $'\e[38;5;209m'    # orange  — warnings
    ok      $'\e[38;5;114m'    # green   — good news
    bold    $'\e[1m'
    reset   $'\e[0m'
)

# Fills TH_C_<name> for this call: the real escape when colour is on, the empty
# string when it is not.
#
# It has to be a plain call, NOT `$(th_paint title)`. Inside a command
# substitution stdout is a pipe, so the tty test above is false and every
# colour silently comes back empty — which looks exactly like a working
# monochrome theme. That was a real bug here, not a hypothetical.
th_load_colors() {
    local on=0 k
    th_use_color && on=1
    for k in ${(k)TH_PALETTE}; do
        if (( on )); then
            typeset -g "TH_C_$k"="${TH_PALETTE[$k]}"
        else
            typeset -g "TH_C_$k"=""
        fi
    done
}

# How wide is the terminal? zsh keeps COLUMNS current, including across a
# resize. 80 is the fallback when there is no terminal at all (a pipe, a cron
# job), which is also the width people write help for.
#
# The fallback has to test the VALUE, not just its emptiness. Off a tty zsh
# sets COLUMNS to `0`, not to nothing, and `${COLUMNS:-80}` does not catch a
# zero — so every th_row took the narrow-terminal path with a NEGATIVE wrap
# width and emitted one word per line. get_mac_help came out at 787 lines
# instead of 132, which reads as a runaway rather than as a layout bug, and it
# quietly falsified the README's claim that `get_git_help > notes.txt` comes
# out clean. Measured, not guessed: `zsh -c 'echo $COLUMNS'` prints 0.
th_cols() {
    local c=${COLUMNS:-0}
    [[ $c == <-> ]] || c=0      # non-numeric is no answer either
    (( c == 0 )) && c=80        # no terminal at all
    (( c < 20 )) && c=20        # a real but absurd width: keep th_wrap positive
    print -r -- $c
}

# How TALL is the terminal? Exactly the same trap as th_cols: zsh reports LINES
# as `0` off a tty, not as nothing, so ${LINES:-24} never fires where it is
# most needed. 24 is the fallback because it is what a terminal was when the
# convention was set and it is still the smallest thing anyone opens.
th_rows() {
    local r=${LINES:-0}
    [[ $r == <-> ]] || r=0
    (( r == 0 )) && r=24
    (( r < 5 )) && r=5
    print -r -- $r
}

# Wrap TEXT to WIDTH at word boundaries, one line per output line.
#
# A word longer than the width is left to overflow rather than broken: these
# are commands, and a command split across a line boundary is a command you
# cannot copy. Better one ragged line than a mangled one.
th_wrap() {  # th_wrap <width> <text...>
    local w=$1; shift
    local text="$*"
    # ${(m)#...} is display width; ${#...} is characters. An emoji is one
    # character and two columns, so measuring characters puts every line with
    # one a column or two past the edge — which is precisely the wrap this
    # function exists to prevent.
    (( ${(m)#text} <= w )) && { print -r -- "$text"; return }
    local -a words out
    words=(${=text})
    local line=""
    local word
    for word in $words; do
        if [[ -z $line ]]; then
            line=$word
        elif (( ${(m)#line} + 1 + ${(m)#word} <= w )); then
            line="$line $word"
        else
            out+=("$line"); line=$word
        fi
    done
    [[ -n $line ]] && out+=("$line")
    print -rl -- $out
}

th_head() {  # th_head <emoji> <title>
    th_load_colors
    local width=${TH_WIDTH:-64}
    local max=$(( $(th_cols) - 2 ))
    (( width > max )) && width=$max
    (( width < 8 )) && width=8
    print -r --
    print -r -- "${TH_C_bold}${TH_C_title}$1  $2${TH_C_reset}"
    print -r -- "${TH_C_rule}${(l:$width::─:)}${TH_C_reset}"
}

th_sub() {  # th_sub <emoji> <title> — a heading inside a section
    th_load_colors
    print -r --
    local l first=1
    for l in ${(f)"$(th_wrap $(( $(th_cols) - 4 )) "$1 $2")"}; do
        if (( first )); then
            print -r -- "  ${TH_C_bold}${TH_C_sub}${l}${TH_C_reset}"; first=0
        else
            print -r -- "    ${TH_C_bold}${TH_C_sub}${l}${TH_C_reset}"
        fi
    done
}

th_row() {  # th_row <label> <command...>
    th_load_colors
    local label=$1; shift
    local w=${TH_LABEL_WIDTH:-24}
    local text="$*"
    # 2 leading spaces + the label column + 1 separating space.
    local gutter=$(( 2 + w + 1 ))
    local avail=$(( $(th_cols) - gutter ))

    # On a very narrow terminal the description column is not worth having:
    # give the label its own line rather than a two-character ribbon.
    if (( avail < 24 )); then
        printf '  %s%s%s\n' "$TH_C_label" "$label" "$TH_C_reset"
        local l
        for l in ${(f)"$(th_wrap $(( $(th_cols) - 4 )) "$text")"}; do
            printf '    %s%s%s\n' "$TH_C_cmd" "$l" "$TH_C_reset"
        done
        return
    fi

    # The point of this: a description that does not fit must continue in the
    # DESCRIPTION column, not at the left margin. Wrapped by the terminal it
    # lands under the labels and the two columns stop being columns at all.
    local -a lines
    lines=(${(f)"$(th_wrap $avail "$text")"})
    local pad=$(( w - ${(m)#label} ))
    (( pad < 0 )) && pad=0
    printf '  %s%s%*s%s %s%s%s\n' \
        "$TH_C_label" "$label" "$pad" "" "$TH_C_reset" "$TH_C_cmd" "${lines[1]}" "$TH_C_reset"
    local i
    for (( i = 2; i <= ${#lines}; i++ )); do
        printf '%*s%s%s%s\n' "$gutter" "" "$TH_C_cmd" "${lines[i]}" "$TH_C_reset"
    done
}

th_note() {  # th_note <text...> — the caveat the command does not tell you
    th_load_colors
    local w=${TH_LABEL_WIDTH:-24}
    local gutter=$(( 2 + w + 1 ))
    local avail=$(( $(th_cols) - gutter - 2 ))   # "↳ "
    (( avail < 20 )) && { gutter=4; avail=$(( $(th_cols) - 6 )); }

    local -a lines
    lines=(${(f)"$(th_wrap $avail "$*")"})
    printf '%*s%s↳ %s%s\n' "$gutter" "" "$TH_C_note" "${lines[1]}" "$TH_C_reset"
    local i
    for (( i = 2; i <= ${#lines}; i++ )); do
        # Aligned under the text, not under the arrow: the arrow marks the note,
        # it does not repeat on every line of it.
        printf '%*s%s%s%s\n' "$(( gutter + 2 ))" "" "$TH_C_note" "${lines[i]}" "$TH_C_reset"
    done
}

th_text() {  # th_text <text...> — a free line, indented to the section body
    th_load_colors
    local l
    for l in ${(f)"$(th_wrap $(( $(th_cols) - 4 )) "$*")"}; do
        print -r -- "  ${TH_C_note}${l}${TH_C_reset}"
    done
}

th_warn() {
    th_load_colors
    print -r -- "  ${TH_C_warn}⚠  $*${TH_C_reset}"
}

th_ok() {
    th_load_colors
    print -r -- "  ${TH_C_ok}✓  $*${TH_C_reset}"
}
