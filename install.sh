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
LINK=0

# Where the runtime is INSTALLED. Not the clone: ~/.zshrc must not name a path
# that exists only on the machine the install was run from. A clone lives on a
# work share, in ~/src, in /tmp — none of which is true on the next machine,
# and when the path is wrong the source fails, th_source_user is never defined,
# and the user's own settings file silently never loads.
TH_INSTALL_DIR="${TH_INSTALL_DIR:-$HOME/.terminal-help}"

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
  --uninstall                   remove the block, and the installed copy in ~/.terminal-help
  --link                        symlink the clone instead of copying it (for
                                working ON terminal-help, not with it)
  --help                        this message
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --targets) TARGETS="$2"; shift 2 ;;
        --targets=*) TARGETS="${1#*=}"; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        --link)    LINK=1; shift ;;
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

    # Everything here is written to stderr on purpose: this function's stdout
    # is captured by the caller, so a single stray line of menu becomes a
    # "target" and the install fails with "unknown target: Which".
    {
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
    } >&2

    local reply=""
    if [ "$ASSUME_YES" -eq 1 ]; then
        reply="$default_choice"; say "$reply" >&2
    elif [ -t 0 ]; then
        read -r reply || true
    else
        # No terminal to ask (piped installer): take the detected default.
        reply="$default_choice"
        say "$reply" >&2
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

# Copy the runtime into $HOME so the rc block can reference $HOME and nothing
# else. Program files only — the user's settings file is never in here.
install_runtime() {
    if [ "$LINK" -eq 1 ]; then
        if [ -e "$TH_INSTALL_DIR" ] && [ ! -L "$TH_INSTALL_DIR" ]; then
            rm -rf "$TH_INSTALL_DIR"
        else
            rm -f "$TH_INSTALL_DIR"
        fi
        ln -s "$TH_DIR" "$TH_INSTALL_DIR"
        ok "linked $TH_INSTALL_DIR → $TH_DIR"
        note "--link: edits in the clone are live. Do not use this on a machine"
        note "that only consumes terminal-help — the clone must never move."
        return 0
    fi

    [ -L "$TH_INSTALL_DIR" ] && rm -f "$TH_INSTALL_DIR"
    mkdir -p "$TH_INSTALL_DIR/lib" "$TH_INSTALL_DIR/help"
    # Replaced wholesale so a file deleted upstream does not linger. Only ever
    # these two directories — the user's help directory is somewhere else
    # entirely, precisely so that this line can be this blunt.
    rm -f "$TH_INSTALL_DIR"/lib/*.zsh "$TH_INSTALL_DIR"/help/*.help.sh 2>/dev/null || true
    cp "$TH_DIR/terminal-help.zsh"      "$TH_INSTALL_DIR/"
    cp "$TH_DIR"/lib/*.zsh              "$TH_INSTALL_DIR/lib/"
    cp "$TH_DIR"/help/*.help.sh         "$TH_INSTALL_DIR/help/"
    cp "$TH_DIR/VERSION"                "$TH_INSTALL_DIR/"
    cp "$TH_DIR/zshrc-user.sh.example"  "$TH_INSTALL_DIR/"
    ok "installed the runtime to $TH_INSTALL_DIR ($(ls "$TH_INSTALL_DIR"/help/*.help.sh | wc -l | tr -d ' ') help files)"
    note "your ~/.zshrc will reference \$HOME, so it works on any machine"
}

install_runtime_powershell() {
    mkdir -p "$1/powershell"
    cp "$TH_DIR/powershell/TerminalHelp.ps1"           "$1/powershell/"
    cp "$TH_DIR/powershell/profile-user.ps1.example"   "$1/powershell/"
    cp "$TH_DIR/VERSION"                               "$1/"
}

# Ask before touching anything. Declining must leave the file exactly as it
# was — so the prompt comes BEFORE the block is stripped, never after.
confirm() {  # confirm <question> ; default yes
    if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
        return 0
    fi
    printf '  %s%s [Y/n]: %s' "$C_L" "$1" "$C_R"
    local reply=""
    read -r reply || true
    say ""
    case "$reply" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

# The block. Its first lines are the point: they tell whoever opens ~/.zshrc
# where their own settings belong, which is not this file.
rc_block() {
    cat <<BLOCK
$BEGIN_MARK
# Put YOUR shell settings in ~/.zshrc-user.sh — aliases, exports, PATH, and
# the get_user_info / user_on_load hooks. NOT in this file: everything between
# these two markers is rewritten by terminal-help's installer.
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

# ~/.zshrc-user.sh belongs to the user, not to this installer.
#
# Created when it is absent. Otherwise IGNORED — not read, not parsed, not
# copied, not backed up, not migrated, not diffed. Whatever is in it is none of
# this script's business, which is what makes an upgrade safe to run blind.
ensure_user_file() {
    local user_file="$1"
    if [ -e "$user_file" ]; then
        ok "$(basename "$user_file") already exists — ignored, it is yours"
        return 0
    fi
    cat > "$user_file" <<'USERFILE'
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
# terminal-help also calls these two functions if you define them:
#
#   get_user_info     your own reference sections, printed on demand
#   user_on_load      runs on every new shell (the only thing that prints
#                     at startup besides the version line)
#
# For a worked example of both, see zshrc-user.sh.example in the
# terminal-help clone.
USERFILE
    chmod 600 "$user_file" 2>/dev/null || true
    ok "created $(basename "$user_file") (mode 600)"
    note "it is yours from here on — this installer never reads or writes it again"
}

# ~/.zshrc-help.d — where the user's own help files go. Created once, then
# never touched: it is content, like the settings file, not program files.
ensure_help_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        ok "$(basename "$dir")/ already exists — ignored, it is yours ($(ls "$dir"/*.help.sh 2>/dev/null | wc -l | tr -d ' ') help file(s))"
        return 0
    fi
    mkdir -p "$dir"
    # Named .txt on purpose: only *.help.sh is loaded, so the example sits
    # there as documentation without becoming a section nobody asked for.
    cat > "$dir/README.txt" <<'HELPDOC'
Your own help sections go here.

Any file named *.help.sh in this directory is sourced on every new shell, and
this directory is never touched by a terminal-help upgrade.

  ~/.zshrc-help.d/docker.help.sh
  ------------------------------
  th_register get_docker_info "🐳 Docker: build, run, compose"

  get_docker_info() {
      th_head "🐳" "Docker"
      th_row  "Build:"   "docker build -t {name} ."
      th_note "--platform linux/amd64 when the target is not an M-series Mac"
      th_sub  "🧩" "Compose"
      th_row  "Up:"      "docker compose up -d"
  }

Then `get_docker_info` prints it, and `get_help` lists it under 🧩 Yours.

The th_register line is optional — a file that only defines get_*_info
functions is still found and listed, by its filename. Registering just gives
the row a better description.

Helpers available: th_head, th_sub, th_row, th_note, th_text, th_warn, th_ok.

Reusing a built-in name (a git.help.sh defining get_git_info) OVERRIDES the
built-in rather than duplicating it — yours is loaded second and wins.
HELPDOC
    ok "created $(basename "$dir")/ for your own help files"
    note "drop a *.help.sh in it — see $dir/README.txt"
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

    local home_dir="${ZDOTDIR:-$HOME}"
    local rc="$home_dir/.zshrc"
    local user_file="$home_dir/.zshrc-user.sh"

    if [ "$UNINSTALL" -eq 1 ]; then
        strip_block "$rc"
        ok "removed the terminal-help block from $rc"
        if [ -e "$TH_INSTALL_DIR" ]; then
            rm -rf "$TH_INSTALL_DIR"
            ok "removed the installed runtime at $TH_INSTALL_DIR"
        fi
        note "$user_file and $home_dir/.zshrc-help.d were left alone — they are yours"
        return 0
    fi

    if ! confirm "Update $rc so terminal-help loads in every shell?"; then
        note "nothing was changed. To wire it up by hand, add this to $rc:"
        say ""
        rc_block | sed "s/^/    ${C_L}/;s/\$/${C_R}/"
        say ""
        note "then create $user_file for your own settings"
        return 0
    fi

    install_runtime
    strip_block "$rc"
    rc_block >> "$rc"
    ok "added the terminal-help block to $rc"
    ensure_user_file "$user_file"
    ensure_help_dir "$home_dir/.zshrc-help.d"
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
        say "    ${C_L}\$env:TH_HOME = Join-Path \$HOME \".terminal-help\"${C_R}"
        say "    ${C_L}. \"\$env:TH_HOME\\powershell\\TerminalHelp.ps1\"${C_R}"
        return 0
    fi

    if [ "$UNINSTALL" -eq 1 ]; then
        strip_block "$profile"
        ok "removed the terminal-help block from $profile"
        return 0
    fi

    if ! confirm "Update $profile so terminal-help loads in every PowerShell?"; then
        note "nothing was changed. Add these two lines to \$PROFILE by hand:"
        say "    ${C_L}\$env:TH_HOME = Join-Path \$HOME \".terminal-help\"${C_R}"
        say "    ${C_L}. \"\$env:TH_HOME\\powershell\\TerminalHelp.ps1\"${C_R}"
        return 0
    fi

    mkdir -p "$(dirname "$profile")"
    strip_block "$profile"

    install_runtime_powershell "$TH_INSTALL_DIR"
    ok "installed the PowerShell runtime to $TH_INSTALL_DIR"
    {
        printf '%s\n' "$BEGIN_MARK"
        printf '# Put YOUR PowerShell settings in profile-user.ps1 beside this file.\n'
        printf '$env:TH_HOME = Join-Path $HOME ".terminal-help"\n'
        printf '. "$env:TH_HOME\\powershell\\TerminalHelp.ps1"\n'
        printf '%s\n' "$END_MARK"
    } >> "$profile"
    ok "added the terminal-help block to $profile"
    note "PowerShell must allow local scripts: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
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

head_ "🏁 Done"
if [ "$UNINSTALL" -eq 1 ]; then
    ok "terminal-help removed. The repository itself was not deleted."
else
    ok "terminal-help v$VERSION installed from $TH_DIR"
    note "open a new shell, then type: get_help"
fi
