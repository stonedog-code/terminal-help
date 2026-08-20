#!/usr/bin/env bash
#
# terminal-help installer.
#
#   ./install.sh              ask which platforms to set up
#   ./install.sh --targets mac,linux,windows --yes    non-interactive
#   ./install.sh --uninstall  remove the blocks it added
#
# What it does, per target: makes sure the shell can find terminal-help by
# adding ONE marked block to your existing rc file. It never overwrites your
# rc, and re-running it replaces its own block rather than appending another.

set -euo pipefail

TH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(cat "$TH_DIR/VERSION" 2>/dev/null || echo unknown)"
BEGIN_MARK="# >>> terminal-help >>>"
END_MARK="# <<< terminal-help <<<"

ASSUME_YES=0
UNINSTALL=0
TARGETS=""

# --- pretty ----------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_T=$'\033[38;5;39m'; C_L=$'\033[38;5;252m'; C_N=$'\033[38;5;244m'
    C_OK=$'\033[38;5;114m'; C_W=$'\033[38;5;209m'; C_B=$'\033[1m'; C_R=$'\033[0m'
else
    C_T=; C_L=; C_N=; C_OK=; C_W=; C_B=; C_R=
fi
say()  { printf '%s\n' "$*"; }
head_() { printf '\n%s%s%s%s\n' "$C_B" "$C_T" "$*" "$C_R"; }
ok()   { printf '  %s✓  %s%s\n' "$C_OK" "$*" "$C_R"; }
warn() { printf '  %s⚠  %s%s\n' "$C_W" "$*" "$C_R"; }
note() { printf '  %s↳  %s%s\n' "$C_N" "$*" "$C_R"; }

usage() {
    cat <<USAGE
terminal-help v$VERSION installer

  --targets mac,linux,windows   which platforms to set up (default: ask)
  --yes                         accept defaults, ask nothing
  --uninstall                   remove the terminal-help block from your rc files
  --help                        this message
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --targets) TARGETS="$2"; shift 2 ;;
        --targets=*) TARGETS="${1#*=}"; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) warn "unknown option: $1"; usage; exit 2 ;;
    esac
done

# --- what is this machine --------------------------------------------------
detect_platform() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        Darwin) echo mac ;;
        Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        *) echo unknown ;;
    esac
}
PLATFORM="$(detect_platform)"

# --- the multi-select ------------------------------------------------------
choose_targets() {
    local default_choice
    case "$PLATFORM" in
        mac) default_choice=1 ;;
        linux) default_choice=2 ;;
        wsl) default_choice="2,3" ;;
        windows) default_choice=3 ;;
        *) default_choice=2 ;;
    esac

    head_ "🧰 terminal-help v$VERSION"
    say "  Which shells should it be installed for? Pick as many as apply."
    say ""
    say "    ${C_B}1${C_R}  🍎  macOS       — adds a source line to ~/.zshrc"
    say "    ${C_B}2${C_R}  🐧  Linux       — adds a source line to ~/.zshrc"
    say "    ${C_B}3${C_R}  🪟  Windows     — adds a line to your PowerShell \$PROFILE"
    say "    ${C_B}4${C_R}  🌍  All three"
    say ""
    note "detected: $PLATFORM"
    printf '  %sNumbers, comma or space separated [%s]: %s' "$C_L" "$default_choice" "$C_R"

    local reply=""
    if [ "$ASSUME_YES" -eq 1 ]; then
        reply="$default_choice"; say "$reply"
    else
        read -r reply || true
    fi
    [ -n "$reply" ] || reply="$default_choice"

    local out=""
    case "$reply" in *4*) out="mac linux windows" ;; esac
    if [ -z "$out" ]; then
        case "$reply" in *1*) out="$out mac" ;; esac
        case "$reply" in *2*) out="$out linux" ;; esac
        case "$reply" in *3*) out="$out windows" ;; esac
    fi
    echo "$out"
}

# --- rc file surgery -------------------------------------------------------
# Idempotent: strips any previous block, then appends the current one.
strip_block() {  # strip_block <file>
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

install_zsh_target() {
    local label="$1" emoji="$2"
    head_ "$emoji  $label"

    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh is not installed."
        case "$label" in
            macOS) note "macOS ships zsh — check /bin/zsh, then: chsh -s /bin/zsh" ;;
            *)     note "sudo apt install -y zsh   (or dnf/pacman/apk), then: chsh -s \$(which zsh)" ;;
        esac
    else
        ok "zsh found: $(zsh --version 2>/dev/null | head -n1)"
        case "${SHELL:-}" in
            *zsh) ok "zsh is your login shell" ;;
            *)    warn "your login shell is ${SHELL:-unset}"
                  note "make it zsh with: chsh -s \$(command -v zsh)   (applies at next login)" ;;
        esac
    fi

    local rc="${ZDOTDIR:-$HOME}/.zshrc"
    strip_block "$rc"
    if [ "$UNINSTALL" -eq 1 ]; then
        ok "removed the terminal-help block from $rc"
        return 0
    fi

    {
        printf '%s\n' "$BEGIN_MARK"
        printf 'export TH_HOME=%s\n' "\"$TH_DIR\""
        printf 'source "$TH_HOME/terminal-help.zsh"\n'
        printf '%s\n' "$END_MARK"
    } >> "$rc"
    ok "added the terminal-help block to $rc"
    note "open a new terminal, or run: source $rc"
}

# Best effort from WSL / Git Bash: find the Windows PowerShell profile.
windows_profile_path() {
    local base=""
    if [ -n "${USERPROFILE:-}" ] && [ -d "$USERPROFILE" ]; then
        base="$USERPROFILE"
    elif [ -d /mnt/c/Users ]; then
        local u="${WIN_USER:-${USER:-}}"
        [ -d "/mnt/c/Users/$u" ] || u="$(ls /mnt/c/Users 2>/dev/null | grep -v -e '^Public$' -e '^Default' -e '^All Users$' | head -n1)"
        [ -n "$u" ] && base="/mnt/c/Users/$u"
    fi
    [ -n "$base" ] || return 1
    for d in "$base/OneDrive/Documents/PowerShell" "$base/Documents/PowerShell"; do
        [ -d "$(dirname "$d")" ] && { echo "$d/Microsoft.PowerShell_profile.ps1"; return 0; }
    done
    return 1
}

install_windows_target() {
    head_ "🪟  Windows (PowerShell)"

    local win_dir="$TH_DIR"
    command -v wslpath >/dev/null 2>&1 && win_dir="$(wslpath -w "$TH_DIR" 2>/dev/null || echo "$TH_DIR")"

    local profile
    if ! profile="$(windows_profile_path)"; then
        warn "could not find your Windows PowerShell profile from here."
        note "run this in PowerShell instead:"
        say ""
        say "    ${C_L}powershell -ExecutionPolicy Bypass -File \"$win_dir\\powershell\\install.ps1\"${C_R}"
        say ""
        note "or add these two lines to \$PROFILE by hand:"
        say "    ${C_L}\$env:TH_HOME = \"$win_dir\"${C_R}"
        say "    ${C_L}. \"\$env:TH_HOME\\powershell\\TerminalHelp.ps1\"${C_R}"
        return 0
    fi

    mkdir -p "$(dirname "$profile")"
    strip_block "$profile"
    if [ "$UNINSTALL" -eq 1 ]; then
        ok "removed the terminal-help block from $profile"
        return 0
    fi

    {
        printf '%s\n' "$BEGIN_MARK"
        printf '$env:TH_HOME = "%s"\n' "$win_dir"
        printf '. "$env:TH_HOME\\powershell\\TerminalHelp.ps1"\n'
        printf '%s\n' "$END_MARK"
    } >> "$profile"
    ok "added the terminal-help block to $profile"
    note "PowerShell must allow local scripts: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}

# --- the private half ------------------------------------------------------
offer_user_file() {
    [ "$UNINSTALL" -eq 1 ] && return 0
    head_ "🔒  Your private half"
    if [ -f "$TH_DIR/user.sh" ]; then
        ok "user.sh already exists — left untouched"
        return 0
    fi
    say "  Connection details, hostnames and personal aliases live in user.sh,"
    say "  which is gitignored and never committed."
    local reply="y"
    if [ "$ASSUME_YES" -eq 0 ]; then
        printf '  %sCreate user.sh from the example now? [Y/n]: %s' "$C_L" "$C_R"
        read -r reply || true
        [ -n "$reply" ] || reply="y"
    fi
    case "$reply" in
        [Yy]*) cp "$TH_DIR/user.sh.example" "$TH_DIR/user.sh"
               chmod 600 "$TH_DIR/user.sh"
               ok "created user.sh (mode 600) — edit it: \$EDITOR $TH_DIR/user.sh" ;;
        *)     note "skipped. Copy it yourself: cp user.sh.example user.sh" ;;
    esac
}

# --- run -------------------------------------------------------------------
if [ -z "$TARGETS" ]; then
    SELECTED="$(choose_targets)"
else
    SELECTED="$(echo "$TARGETS" | tr ',' ' ')"
    case "$SELECTED" in *all*) SELECTED="mac linux windows" ;; esac
fi

if [ -z "$SELECTED" ]; then
    warn "nothing selected — nothing to do."
    exit 0
fi

DID_ZSH=0
for t in $SELECTED; do
    case "$t" in
        mac)     install_zsh_target "macOS" "🍎"; DID_ZSH=1 ;;
        linux)   [ "$DID_ZSH" -eq 1 ] && { note "Linux uses the same ~/.zshrc — already done."; continue; }
                 install_zsh_target "Linux" "🐧"; DID_ZSH=1 ;;
        windows) install_windows_target ;;
        *)       warn "unknown target: $t" ;;
    esac
done

offer_user_file

head_ "🏁 Done"
if [ "$UNINSTALL" -eq 1 ]; then
    ok "terminal-help removed. The repository itself was not deleted."
else
    ok "terminal-help v$VERSION installed from $TH_DIR"
    note "open a new shell, then type: get_help"
fi
