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

    local l                       # shared loop variable: see the note below
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
            if (( ${TH_USER_STATUS:-0} == 126 )); then
                th_warn "it STOPPED EARLY (126) — everything below the failing line"
                th_text "never ran. A builtin misused at file scope does this, and the"
                th_text "usual cause is prose that lost its leading '#'. See below."
                th_text "Read the first error with: zsh -f -c 'source $user_file'"
                (( problems++ ))
            elif (( ${TH_USER_STATUS:-0} )); then
                th_ok "it ran to the end"
                th_text "its last command returned ${TH_USER_STATUS}, which is that command's"
                th_text "own status — not a loading problem. (connect_work with the"
                th_text "share unreachable looks exactly like this.)"
            else
                th_ok "it loaded cleanly"
            fi
        else
            th_warn "it was never loaded — nothing called th_source_user"
            (( problems++ ))
        fi
        th_row "Defines:" "$(_th_doctor_defined get_user_info user_on_load)"
    fi

    # The most common cause after a copy-paste: prose at the start of a line,
    # where a comment marker was lost. Only two shapes are worth reporting, and
    # both were measured rather than guessed:
    #
    #   `private file, so ...`  a builtin followed by a bare word ending in a
    #                           comma — this ABORTS the file (exit 126)
    #   `--------------------`  a separator line, which is merely noisy
    #
    # An earlier version used a catch-all "does not look like code" regex and
    # flagged closing braces and quoted exports in a perfectly healthy file.
    # A detector that cries wolf on good input is worse than none: it teaches
    # people to scroll past the one section that matters.
    if [[ -r $user_file ]]; then
        local -a fatal noisy
        fatal=(${(f)"$(grep -nE '^[[:space:]]*(private|local|typeset|declare|readonly|float|integer)[[:space:]]+[A-Za-z][A-Za-z0-9_]*,' "$user_file" 2>/dev/null)"})
        noisy=(${(f)"$(grep -nE '^[[:space:]]*-{5,}[[:space:]]*$' "$user_file" 2>/dev/null)"})
        fatal=(${fatal:#}); noisy=(${noisy:#})

        if (( ${#fatal} )); then
            th_sub "✂️" "Lines that ABORT the file (a lost '#')"
                for l in ${fatal}; do th_text "  $l"; done
            th_text "Each starts with a word zsh knows as a builtin. Misused at file"
            th_text "scope that does not merely error — it stops the file, so nothing"
            th_text "below it is defined. Put the '#' back."
            (( problems++ ))
        fi
        if (( ${#noisy} )); then
            th_sub "✂️" "Separator lines without a leading '#'"
                for l in ${noisy}; do th_text "  $l"; done
            th_text "Harmless — they only print 'command not found' — but they are a"
            th_text "sign the comment markers were lost when this was pasted."
        fi
    fi

    th_sub "🧩" "Your help files"
    th_row "Directory:" "$help_dir"
    if [[ -d $help_dir ]]; then
        local -a hfiles
        hfiles=($help_dir/**/*.help.sh(N))
        th_row "Files:" "${#hfiles} *.help.sh"
        local f bad=0
        for f in $help_dir/**/*.help.sh(N); do
            [[ -n $(whence -p zsh) ]] || break
            zsh -n "$f" 2>/dev/null || { th_warn "does not parse: ${f/#$HOME/~}"; bad=1; (( problems++ )) }
        done
        if (( ${#hfiles} == 0 )); then
            th_text "none yet — a *.help.sh here becomes a topic of your own"
        elif (( ! bad )); then
            th_ok "all ${#hfiles} parse"
        fi
    else
        th_text "not created yet — install.sh makes it"
    fi

    th_sub "🗂" "Topics"
    local manifest="${TH_SELECTED:-$TH_HOME/selected}"
    # Split the loaded topics: the manifest is a statement about PACKAGE topics
    # only, so mixing yours into the comparison below compares two different
    # sets and calls the difference drift.
    local -a loaded_pkg loaded_user
    local t
    for t in ${TH_TOPIC_ORDER}; do
        if [[ ${TH_TOPIC_CATEGORY[$t]} == user ]]; then
            loaded_user+=("$t")
        else
            loaded_pkg+=("$t")
        fi
    done
    th_row "Loaded in THIS shell:" "${(j:, :)loaded_pkg}"
    if (( ${#loaded_user} )); then
        th_row "Yours, always on:" "${(j:, :)loaded_user}"
        th_note "your own topics are never in the manifest — they load from"
        th_note "${TH_USER_HELP_DIR/#$HOME/~} on every shell, selected or not"
    fi
    th_row "Manifest on disk:" "$manifest"
    if [[ -r $manifest ]]; then
        local -a on_disk
        on_disk=(${(f)"$(th_selected_topics)"})
        th_row "It selects:" "${(j:, :)${(@o)on_disk}}"
        # Running the installer does not change the shell you ran it from.
        #
        # PACKAGE topics only. th_available_topics skips help/user, so the
        # manifest can never list a topic of yours — comparing it against every
        # loaded topic meant one *.help.sh of your own made this warn on every
        # shell, and the reload it advises could never clear it.
        if [[ "${(j: :)${(@o)on_disk}}" != "${(j: :)${(@o)loaded_pkg}}" ]]; then
            th_warn "this shell was started before the manifest last changed"
            th_text "open a new shell (or: source ~/.zshrc) to pick it up"
        fi
    fi
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
