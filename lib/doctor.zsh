#!/usr/bin/env zsh
# 🩺 th_doctor — why isn't my help (or my settings file) doing anything?
#
# Written after a real case: a settings file whose comment markers were lost
# when it was copied, leaving prose at the start of a line. One of those lines
# began with the word `private`, which zsh has as a BUILTIN, and a builtin used
# wrongly at file scope aborts the rest of the file. Everything below it — the
# functions, the calls that print at startup — silently never existed. The one
# error line had long scrolled past.
#
# Every check prints what it examined, not just a verdict.

th_doctor() {
    th_head "🩺" "terminal-help doctor"

    local rc="${ZDOTDIR:-$HOME}/.zshrc"
    local user_file="${TH_USER_FILE:-${ZDOTDIR:-$HOME}/.zshrc-user.sh}"
    local help_dir="${TH_USER_HELP_DIR:-${ZDOTDIR:-$HOME}/.zshrc-help.d}"
    local problems=0

    th_sub "📦" "The install"
    th_row "Version:"   "v${TH_VERSION:-unknown}"
    th_row "TH_HOME:"   "${TH_HOME:-<unset>}"
    if [[ -r "$TH_HOME/terminal-help.zsh" ]]; then
        th_ok "the runtime is where \$TH_HOME says it is"
    else
        th_warn "no runtime at \$TH_HOME — re-run install.sh from the clone"
        (( problems++ ))
    fi
    if grep -q '>>> terminal-help >>>' "$rc" 2>/dev/null; then
        th_ok "${rc:t} has the terminal-help block"
        local blockhome=$(grep -m1 'TH_HOME=' "$rc" 2>/dev/null)
        [[ $blockhome == *'$HOME'* ]] || {
            th_warn "the block hardcodes a path instead of \$HOME:"
            th_text "  $blockhome"
            th_text "  that path exists on one machine only — re-run install.sh"
            (( problems++ ))
        }
    else
        th_warn "${rc:t} has no terminal-help block — re-run install.sh"
        (( problems++ ))
    fi

    th_sub "🔒" "Your settings file"
    th_row "Path:" "$user_file"
    if [[ ! -e $user_file ]]; then
        th_warn "does not exist — nothing of yours can load"
        (( problems++ ))
    elif [[ ! -r $user_file ]]; then
        th_warn "exists but is not readable (mode $(stat -f %Lp "$user_file" 2>/dev/null || stat -c %a "$user_file" 2>/dev/null))"
        (( problems++ ))
    else
        # Lines, and then the number that actually decides whether anything
        # happens: a file of pure comments loads perfectly and prints nothing,
        # which looks exactly like a file that never loaded at all.
        local total live
        total=$(wc -l < "$user_file" | tr -d ' ')
        # grep -c exits 1 on a count of zero, so `|| print 0` appended a second
        # zero and the arithmetic below choked. Count lines instead.
        live=$(grep -vE '^[[:space:]]*(#|$)' "$user_file" 2>/dev/null | wc -l | tr -d ' ')
        th_row "Size:" "$total lines, $live of them executable"
        if [[ -L $user_file ]]; then
            th_row "It is a symlink to:" "$(readlink "$user_file")"
            [[ -r $user_file ]] || th_warn "and the target cannot be read from here"
        fi
        if (( live == 0 )); then
            th_warn "it contains NO executable lines — only comments and blanks."
            th_text "That is what a freshly installed file looks like: it loads"
            th_text "cleanly and prints nothing, which is indistinguishable from"
            th_text "not loading at all. If you copied a file here, check it"
            th_text "landed: ls -l \"$user_file\""
            (( problems++ ))
        else
            th_text "first executable lines:"
            local l
            for l in ${(f)"$(grep -vE '^[[:space:]]*(#|$)' "$user_file" 2>/dev/null | head -3)"}; do
                th_text "  $l"
            done
        fi
        # zsh -n is the honest check: it parses without running anything.
        local errs zsh_bin
        zsh_bin=$(whence -p zsh 2>/dev/null)
        if [[ -z $zsh_bin ]]; then
            th_text "no zsh on PATH to parse-check with — skipped (not a failure)"
        elif errs=$($zsh_bin -n "$user_file" 2>&1); then
            th_ok "it parses"
        else
            th_warn "it does NOT parse:"
            th_text "  ${errs}"
            (( problems++ ))
        fi
        if [[ -n $TH_USER_SOURCED ]]; then
            if (( ${TH_USER_STATUS:-0} )); then
                th_warn "it returned exit $TH_USER_STATUS. That is one of two things:"
                th_text "  · it stopped early at an error, and everything below that"
                th_text "    line never ran — a misused builtin does this; or"
                th_text "  · it ran to the end and its LAST command simply failed"
                th_text "    (connect_work with the share unreachable, say)"
                th_text "To tell them apart, run it on its own and read the first error:"
                th_text "  zsh -f -c 'source $user_file'"
                th_text "Then check something defined at the BOTTOM of the file exists."
                (( problems++ ))
            else
                th_ok "it loaded cleanly"
            fi
        else
            th_warn "it was never loaded — nothing called th_source_user"
            (( problems++ ))
        fi
        th_row "Defines:" "$(_th_doctor_defined get_user_info user_on_load)"
    fi

    # The most common cause after a copy-paste: prose at the start of a line.
    # A comment marker is one character, and losing it turns documentation into
    # commands — or, worse, into a builtin like `private` that stops the file.
    if [[ -r $user_file ]]; then
        local -a suspects
        suspects=(${(f)"$(grep -nE '^[[:space:]]*(private|local|typeset|declare|readonly|export)[[:space:]]+[a-zA-Z]+,' "$user_file" 2>/dev/null)"})
        suspects+=(${(f)"$(grep -nE '^[[:space:]]*(-{3,}|[^[:alnum:][:space:]#_$"'"'"'({\[/.!*@-][^=]*)$' "$user_file" 2>/dev/null | head -5)"})
        if (( ${#suspects} )); then
            th_sub "✂️" "Lines that look like prose without a leading #"
            local l
            for l in ${suspects}; do [[ -n $l ]] && th_text "  $l"; done
            th_text "A comment needs its '#'. A line starting with a word zsh knows as"
            th_text "a builtin (private, local, typeset) does not merely error — it"
            th_text "ABORTS the file, so nothing below it is defined."
            (( problems++ ))
        fi
    fi

    th_sub "🧩" "Your help files"
    th_row "Directory:" "$help_dir"
    if [[ -d $help_dir ]]; then
        th_row "Files:" "$(print -l -- $help_dir/**/*.help.sh(N) | grep -c . ) *.help.sh"
        local f bad=0
        for f in $help_dir/**/*.help.sh(N); do
            [[ -n $(whence -p zsh) ]] || break
            zsh -n "$f" 2>/dev/null || { th_warn "does not parse: ${f/#$HOME/~}"; bad=1; (( problems++ )) }
        done
        (( bad )) || th_ok "all of them parse"
    else
        th_text "not created yet — install.sh makes it"
    fi

    th_sub "🗂" "Topics"
    th_row "Selected:" "${(j:, :)TH_TOPIC_ORDER}"
    th_row "Manifest:" "${TH_SELECTED:-$TH_HOME/selected}"
    (( ${#TH_ORPHAN_EXTENSIONS} )) && {
        th_warn "extensions for topics that are not loaded: ${(j:, :)${(u)TH_ORPHAN_EXTENSIONS}}"
        th_text "turn one on with: th_topics enable <topic>"
    }

    print -r --
    if (( problems )); then
        th_warn "$problems problem(s) above."
    else
        th_ok "no problems found."
    fi
}

_th_doctor_defined() {
    local fn out=()
    for fn in "$@"; do th_defined "$fn" && out+=("$fn"); done
    (( ${#out} )) && print -r -- "${(j:, :)out}" || print -r -- "none of get_user_info, user_on_load"
}
