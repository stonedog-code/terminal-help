#!/usr/bin/env bash
#
# terminal-help installer.
#
#   ./install.sh                 pick your topics, then install
#   ./install.sh --all --yes     every topic, no questions
#   ./install.sh --topics git,linux,powershell --yes
#   ./install.sh --uninstall     remove the block and ~/.terminal-help
#
# It copies the runtime into ~/.terminal-help and adds ONE marked block to the
# ~/.zshrc you already have. Your own files — ~/.zshrc-user.sh and
# ~/.zshrc-help.d/ — are created once if missing and never touched again.
#
# terminal-help runs in zsh only. PowerShell is a HELP TOPIC here, not a
# runtime: `get_powershell_help` is a reference you read from your own shell.

set -uo pipefail

TH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$TH_DIR/VERSION" 2>/dev/null || echo unknown)"
BEGIN_MARK="# >>> terminal-help >>>"
END_MARK="# <<< terminal-help <<<"

TH_INSTALL_DIR="${TH_INSTALL_DIR:-$HOME/.terminal-help}"
HOME_DIR="${ZDOTDIR:-$HOME}"
USER_FILE="$HOME_DIR/.zshrc-user.sh"
USER_HELP_DIR="$HOME_DIR/.zshrc-help.d"

ASSUME_YES=0; UNINSTALL=0; LINK=0; WANT_ALL=0; TOPICS_ARG=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_T=$'\033[38;5;39m'; C_L=$'\033[38;5;252m'; C_N=$'\033[38;5;244m'
    C_OK=$'\033[38;5;114m'; C_W=$'\033[38;5;209m'; C_B=$'\033[1m'; C_R=$'\033[0m'
else C_T=; C_L=; C_N=; C_OK=; C_W=; C_B=; C_R=; fi
say()   { printf '%s\n' "$*"; }
head_() { printf '\n%s%s%s%s\n' "$C_B" "$C_T" "$*" "$C_R"; }
ok()    { printf '  %s✓  %s%s\n' "$C_OK" "$*" "$C_R"; }
warn()  { printf '  %s⚠  %s%s\n' "$C_W" "$*" "$C_R"; }
note()  { printf '  %s↳  %s%s\n' "$C_N" "$*" "$C_R"; }

# --- am I whole? -----------------------------------------------------------
# Reading this script from a network share can hand bash a PARTIAL file: it
# runs everything it received and then dies at EOF inside an unterminated
# string, AFTER doing the work. That is not a hypothetical — it happened on an
# SMB-mounted clone and produced
#
#     ./install.sh: line 371: unexpected EOF while looking for matching `"'
#
# which reads as a bug in the installer rather than as a half-copied file. The
# last line of this file is a sentinel; if it is not there, we are a fragment.
if [ "$(tail -n 1 "$0" 2>/dev/null)" != "# END-OF-INSTALLER" ]; then
    printf '\n  ⚠  This copy of install.sh is TRUNCATED — it is missing its end.\n' >&2
    printf '     You are running a partial file, so it would do part of the job\n' >&2
    printf '     and then fail with an "unexpected EOF" that is not its fault.\n\n' >&2
    printf '     Lines here: %s\n' "$(wc -l < "$0" | tr -d ' ')" >&2
    printf '     Most likely: the clone is on a network share and was read while\n' >&2
    printf '     it was being written, or the share served a stale cached copy.\n\n' >&2
    printf '     Fix it with one of:\n' >&2
    printf '       git -C "%s" checkout -- install.sh\n' "$(dirname "$0")" >&2
    printf '       cp -f <a local clone>/install.sh "%s"/\n' "$(dirname "$0")" >&2
    printf '     or clone to local disk and run it from there.\n\n' >&2
    exit 1
fi

usage() {
    cat <<USAGE
terminal-help v$VERSION installer

  --topics a,b,c   install with these topics selected (default: ask)
  --all            select every topic
  --yes            accept defaults, ask nothing
  --link           symlink the clone instead of copying (for working ON this)
  --uninstall      remove the block and ~/.terminal-help
  --help           this message

Topics are discovered from help/*/*.help.sh — the same list the menu shows.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --topics) TOPICS_ARG="$2"; shift 2 ;;
        --topics=*) TOPICS_ARG="${1#*=}"; shift ;;
        --all) WANT_ALL=1; shift ;;
        --yes|-y) ASSUME_YES=1; shift ;;
        --link) LINK=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) warn "unknown option: $1"; usage; exit 2 ;;
    esac
done

confirm() {  # default yes
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then return 0; fi
    printf '  %s%s [Y/n]: %s' "$C_L" "$1" "$C_R"
    local reply=""; read -r reply || true; say ""
    case "$reply" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

# --- the catalogue ---------------------------------------------------------
# Read from the fixed header comment, never by sourcing or by parsing shell.
# A bash installer that greps shell CODE is coupled to how that code is
# formatted; one documented line per fact is not.
header_field() { sed -n "1,20{s/^# $2:[[:space:]]*//p;}" "$1" | head -n1; }

topic_files() { find "$TH_DIR/help" -mindepth 2 -name '*.help.sh' -not -path '*/user/*' | sort; }

catalogue() {  # topic<TAB>emoji<TAB>category<TAB>description
    local f name
    while IFS= read -r f; do
        name="$(header_field "$f" TH_TOPIC)"
        [ -n "$name" ] || continue
        printf '%s\t%s\t%s\t%s\n' "$name" "$(header_field "$f" TH_EMOJI)" \
            "$(basename "$(dirname "$f")")" "$(header_field "$f" TH_DESC)"
    done < <(topic_files)
}

detect_platform() {
    case "$(uname -s 2>/dev/null)" in
        Darwin) echo mac ;;
        Linux)  grep -qi microsoft /proc/version 2>/dev/null && echo windows || echo linux ;;
        *) echo "" ;;
    esac
}

choose_topics() {  # everything here goes to stderr; only the list is stdout
    local -a names=() descs=() emojis=()
    local line n e c d
    while IFS=$'\t' read -r n e c d; do names+=("$n"); emojis+=("$e"); descs+=("$c: $d"); done < <(catalogue)

    local platform; platform="$(detect_platform)"
    local default_list="" i
    for i in "${!names[@]}"; do
        case "${names[$i]}" in
            "$platform") default_list="$default_list ${names[$i]}" ;;
            git|python)  default_list="$default_list ${names[$i]}" ;;
        esac
    done
    default_list="${default_list# }"

    {
        head_ "🧰 terminal-help v$VERSION"
        say "  Which topics do you want help for? Everything is installed either"
        say "  way — this chooses what loads, and you can change it later with"
        say "  ${C_B}th_topics${C_R}, with no clone needed."
        say ""
        for i in "${!names[@]}"; do
            printf '    %s%2d%s  %s  %-12s %s%s%s\n' "$C_B" "$((i+1))" "$C_R" \
                "${emojis[$i]}" "${names[$i]}" "$C_N" "${descs[$i]}" "$C_R"
        done
        say ""
        note "detected platform: ${platform:-unknown}"
        printf '  %sNumbers (comma or space separated), "a" for all [%s]: %s' "$C_L" "$default_list" "$C_R"
    } >&2

    local reply=""
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then reply=""; say "$default_list" >&2
    else read -r reply || true; fi

    if [ -z "$reply" ]; then printf '%s\n' $default_list; return 0; fi
    case "$reply" in [Aa]*) printf '%s\n' "${names[@]}"; return 0 ;; esac

    local token
    for token in $(printf '%s' "$reply" | tr ',' ' '); do
        case "$token" in
            ''|*[!0-9]*) for n in "${names[@]}"; do [ "$n" = "$token" ] && printf '%s\n' "$n"; done ;;
            *) i=$((token-1)); [ -n "${names[$i]:-}" ] && printf '%s\n' "${names[$i]}" ;;
        esac
    done
}

# --- the runtime -----------------------------------------------------------
install_runtime() {
    if [ "$LINK" -eq 1 ]; then
        [ -e "$TH_INSTALL_DIR" ] && [ ! -L "$TH_INSTALL_DIR" ] && rm -rf "$TH_INSTALL_DIR"
        rm -f "$TH_INSTALL_DIR"
        ln -s "$TH_DIR" "$TH_INSTALL_DIR"
        ok "linked $TH_INSTALL_DIR → $TH_DIR"
        note "--link: edits in the clone are live. The clone must never move."
        return 0
    fi

    [ -L "$TH_INSTALL_DIR" ] && rm -f "$TH_INSTALL_DIR"
    mkdir -p "$TH_INSTALL_DIR/lib" "$TH_INSTALL_DIR/help"

    # Shipped categories are replaced wholesale so a file deleted upstream does
    # not linger. Only these, by name — never `rm -rf help/`, and never
    # help/user, which is a symlink to the user's own directory.
    local cat
    for cat in $(find "$TH_DIR/help" -mindepth 1 -maxdepth 1 -type d -not -name user -exec basename {} \;); do
        rm -rf "${TH_INSTALL_DIR:?}/help/$cat"
        mkdir -p "$TH_INSTALL_DIR/help/$cat"
        cp "$TH_DIR/help/$cat"/*.help.sh "$TH_INSTALL_DIR/help/$cat/" 2>/dev/null || true
    done
    rm -f "$TH_INSTALL_DIR"/lib/*.zsh
    cp "$TH_DIR/terminal-help.zsh"     "$TH_INSTALL_DIR/"
    cp "$TH_DIR"/lib/*.zsh             "$TH_INSTALL_DIR/lib/"
    cp "$TH_DIR/VERSION"               "$TH_INSTALL_DIR/"
    # Computed into variables on purpose: bash 3.2 (macOS) mis-parses a single
    # quote inside $( ) inside a double-quoted string — it reads the quote as
    # the outer string's and dies with "unexpected EOF while looking for
    # matching". The script still RAN, then failed to parse its own last line,
    # which is a confusing way to end a successful install.
    local n_topics pretty
    n_topics=$(topic_files | wc -l)
    n_topics=${n_topics// /}
    pretty=${TH_INSTALL_DIR/#$HOME/\~}
    ok "installed $n_topics topics to $pretty"
    note "every topic is installed; the manifest below decides which ones load"
}

write_manifest() {  # write_manifest <topic>...
    local manifest="$TH_INSTALL_DIR/selected"
    { echo "# terminal-help topics — one per line."
      echo "# Change with: th_topics enable <topic> / disable <topic> / all"
      printf '%s\n' "$@"; } > "$manifest"
    ok "selected: $*"
    note "change it any time with th_topics — the clone is not needed again"
}

# ~/.zshrc-help.d is the user's. help/user inside the installed tree is a
# SYMLINK to it: the path is where you were told it would be, while the bytes
# live outside anything the installer deletes. A symlink is removed by rm -rf,
# never followed, so user content cannot be inside the blast radius.
ensure_user_help_dir() {
    if [ ! -d "$USER_HELP_DIR" ]; then
        mkdir -p "$USER_HELP_DIR/extensions"
        cat > "$USER_HELP_DIR/README.txt" <<'HELPDOC'
Your own help lives here. Nothing in this directory is ever touched by a
terminal-help upgrade. It is also reachable as ~/.terminal-help/help/user,
which is a symlink to this directory.

TWO THINGS YOU CAN DO
=====================

1. A TOPIC OF YOUR OWN — any *.help.sh, at any depth (work/, personal/, ...)

   ~/.zshrc-help.d/work/deploy.help.sh
   ------------------------------------
   # TH_TOPIC: deploy
   # TH_EMOJI: 🚀
   # TH_DESC:  our deploy runbook

   _th_help_deploy() {
       th_head "🚀" "Deploy"
       th_row  "Staging:" "./deploy.sh staging"
       th_note "the flag you always forget goes here, where it is private"
   }

   → `get_deploy_help` prints it, and it is listed in get_help under 🧩 Yours.

2. AN EXTENSION — add to a topic that ships with terminal-help

   ~/.zshrc-help.d/extensions/git.help.sh
   --------------------------------------
   _th_ext_git_mine() {
       th_sub "🔧" "My git shortcuts"
       th_row "Fixup:" "git commit --fixup HEAD && git rebase -i --autosquash"
   }
   th_extend git _th_ext_git_mine

   → `get_git_help` prints the built-in content, then yours. The package file
     is not modified, so an upgrade cannot overwrite your additions and your
     additions cannot go stale against the package.

HELPERS: th_head, th_sub, th_row, th_note, th_text, th_warn, th_ok.

CONTRIBUTING SOMETHING BACK: scripts/promote-extensions.sh in the clone
collects your extensions into a report you can fold into the package by hand.
HELPDOC
        local pretty_help=${USER_HELP_DIR/#$HOME/\~}
        ok "created $pretty_help/ for your own help files"
        note "a topic of your own, or an extension to a built-in — see README.txt"
    else
        local n_help
        n_help=$(find "$USER_HELP_DIR" -name "*.help.sh" 2>/dev/null | wc -l)
        n_help=${n_help// /}
        ok "${USER_HELP_DIR##*/}/ already exists — ignored, it is yours ($n_help file(s))"
    fi

    if [ "$LINK" -eq 0 ]; then
        rm -rf "$TH_INSTALL_DIR/help/user"
        ln -s "$USER_HELP_DIR" "$TH_INSTALL_DIR/help/user"
    fi
}

ensure_user_file() {
    if [ -e "$USER_FILE" ]; then
        ok "$(basename "$USER_FILE") already exists — ignored, it is yours"
        return 0
    fi
    cat > "$USER_FILE" <<'USERFILE'
#!/usr/bin/env zsh
#
# ~/.zshrc-user.sh — your shell settings. This file is yours alone: nothing
# installs into it, upgrades never touch it, and it is never committed.
#
# It is sourced on every new shell by the terminal-help block in ~/.zshrc.
# Put your settings HERE rather than in ~/.zshrc, which that block rewrites.
#
#   aliases      alias ll="ls -la"
#   exports      export EDITOR="vim"
#   PATH         path=("$HOME/.local/bin" $path)
#
# Two optional functions terminal-help calls if you define them:
#
#   get_user_info     your own reference section, printed on demand
#   user_on_load      runs on every new shell (the only thing that prints
#                     at startup besides the version line)
#
# Help CONTENT goes somewhere else: ~/.zshrc-help.d/ — see its README.txt.
#
# Everything this file can do is described in these comments. There is no
# separate example file to copy from and get out of step with.
USERFILE
    chmod 600 "$USER_FILE" 2>/dev/null || true
    ok "created $(basename "$USER_FILE") (mode 600)"
}

rc_block() {
    cat <<BLOCK
$BEGIN_MARK
# Put YOUR shell settings in ~/.zshrc-user.sh, and your own help topics in
# ~/.zshrc-help.d/. NOT in this file: everything between these two markers is
# rewritten by terminal-help's installer.
export TH_HOME="\$HOME/.terminal-help"
export TH_USER_FILE="\${ZDOTDIR:-\$HOME}/.zshrc-user.sh"
if [[ -r "\$TH_HOME/terminal-help.zsh" ]]; then
    source "\$TH_HOME/terminal-help.zsh"   # the reference help
    th_source_user                        # your settings, from \$TH_USER_FILE
elif [[ -r "\$TH_USER_FILE" ]]; then
    source "\$TH_USER_FILE"                # help absent — your settings still load
fi
$END_MARK
BLOCK
}

strip_block() {
    local file="$1"
    [ -f "$file" ] || return 0
    if grep -qF "$BEGIN_MARK" "$file" 2>/dev/null; then
        cp "$file" "$file.terminal-help.bak"
        awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
            index($0, b) { skip=1 } !skip { print } index($0, e) { skip=0 }
        ' "$file.terminal-help.bak" > "$file"
        note "backed up $(basename "$file") to $(basename "$file").terminal-help.bak"
    fi
}

# --- run -------------------------------------------------------------------
rc="$HOME_DIR/.zshrc"

if [ "$UNINSTALL" -eq 1 ]; then
    head_ "🧰 terminal-help v$VERSION"
    strip_block "$rc"
    ok "removed the terminal-help block from $rc"
    if [ -e "$TH_INSTALL_DIR" ]; then
        rm -rf "$TH_INSTALL_DIR"        # help/user is a symlink: the target survives
        local pretty_dir=${TH_INSTALL_DIR/#$HOME/\~}
        ok "removed the installed runtime at $pretty_dir"
    fi
    note "$USER_FILE and $USER_HELP_DIR were left alone — they are yours"
    head_ "🏁 Done"
    exit 0
fi

if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh is not installed — terminal-help runs in zsh."
    note "macOS ships it; on Linux: sudo apt install -y zsh (or dnf/pacman/apk)"
fi

SELECTED=()
if [ "$WANT_ALL" -eq 1 ]; then
    while IFS=$'\t' read -r n _ _ _; do SELECTED+=("$n"); done < <(catalogue)
elif [ -n "$TOPICS_ARG" ]; then
    for t in $(printf '%s' "$TOPICS_ARG" | tr ',' ' '); do SELECTED+=("$t"); done
else
    while IFS= read -r t; do [ -n "$t" ] && SELECTED+=("$t"); done < <(choose_topics)
fi

if [ "${#SELECTED[@]}" -eq 0 ]; then
    warn "no topics selected — nothing to do."
    exit 0
fi

head_ "🐚 zsh"
case "${SHELL:-}" in
    *zsh) ok "zsh is your login shell" ;;
    *) warn "your login shell is ${SHELL:-unset}"
       note "make it zsh with: chsh -s \$(command -v zsh)   (applies at next login)" ;;
esac

if ! confirm "Update $rc so terminal-help loads in every shell?"; then
    note "nothing was changed. To wire it up by hand, add this to $rc:"
    say ""; rc_block | sed "s/^/    ${C_L}/;s/\$/${C_R}/"; say ""
    exit 0
fi

install_runtime
write_manifest "${SELECTED[@]}"
ensure_user_file
ensure_user_help_dir
strip_block "$rc"
rc_block >> "$rc"
ok "added the terminal-help block to $rc"

head_ "🏁 Done"
ok "terminal-help v$VERSION installed"
note "open a new shell, then type: get_help"
# END-OF-INSTALLER
