#!/usr/bin/env zsh
# ui.zsh — colour, emoji and layout helpers. Every other lib/*.zsh is written
# in terms of these, so restyling the whole thing is one edit.

# Colour is on when the output is a terminal and nobody asked for it off.
# Decided per call rather than once at load: `get_git_info | less` should not
# be full of escape codes just because the shell that sourced this had a tty.
th_use_color() {
    [[ -n $TH_NO_COLOR || -n $NO_COLOR ]] && return 1
    [[ $TERM == (dumb|) ]] && return 1
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

th_head() {  # th_head <emoji> <title>
    th_load_colors
    local width=${TH_WIDTH:-64}
    print -r --
    print -r -- "${TH_C_bold}${TH_C_title}$1  $2${TH_C_reset}"
    print -r -- "${TH_C_rule}${(l:$width::─:)}${TH_C_reset}"
}

th_sub() {  # th_sub <emoji> <title> — a heading inside a section
    th_load_colors
    print -r --
    print -r -- "  ${TH_C_bold}${TH_C_sub}$1 $2${TH_C_reset}"
}

th_row() {  # th_row <label> <command...>
    th_load_colors
    local label=$1; shift
    printf '  %s%-*s%s %s%s%s\n' \
        "$TH_C_label" "${TH_LABEL_WIDTH:-24}" "$label" "$TH_C_reset" \
        "$TH_C_cmd" "$*" "$TH_C_reset"
}

th_note() {  # th_note <text...> — the caveat the command does not tell you
    th_load_colors
    printf '  %*s %s↳ %s%s\n' "${TH_LABEL_WIDTH:-24}" "" "$TH_C_note" "$*" "$TH_C_reset"
}

th_text() {  # th_text <text...> — a free line, indented to the section body
    th_load_colors
    print -r -- "  ${TH_C_note}$*${TH_C_reset}"
}

th_warn() {
    th_load_colors
    print -r -- "  ${TH_C_warn}⚠  $*${TH_C_reset}"
}

th_ok() {
    th_load_colors
    print -r -- "  ${TH_C_ok}✓  $*${TH_C_reset}"
}
