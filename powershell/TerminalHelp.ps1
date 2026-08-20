<#
    terminal-help — PowerShell edition.

    Dot-source it from your $PROFILE:

        $env:TH_HOME = "C:\path\to\terminal-help"
        . "$env:TH_HOME\powershell\TerminalHelp.ps1"

    Loading is silent apart from one version line. Everything else prints only
    when you ask: type  get_help

    Nothing host-specific lives here. Your own settings live in
    profile-user.ps1 beside your $PROFILE, which may define:

        Show-UserInfo       your own reference sections
        Invoke-UserOnLoad   what runs on every new shell
#>

# --- where am I ------------------------------------------------------------
$script:ThHome    = if ($env:TH_HOME) { $env:TH_HOME } else { Split-Path $PSScriptRoot -Parent }
$script:ThVersion = if (Test-Path "$script:ThHome\VERSION") {
    (Get-Content "$script:ThHome\VERSION" -Raw).Trim()
} else { 'unknown' }

# --- colour ----------------------------------------------------------------
# Raw ANSI. Windows Terminal and PowerShell 7 render it; the legacy conhost of
# Windows PowerShell 5.1 may not — set TH_NO_COLOR=1 there.
$script:ThEsc   = [char]27
$script:ThColor = -not ($env:NO_COLOR -or $env:TH_NO_COLOR)

function script:ThPaint([string]$Key) {
    if (-not $script:ThColor) { return '' }
    switch ($Key) {
        'title' { "$script:ThEsc[38;5;39m" }
        'label' { "$script:ThEsc[38;5;252m" }
        'cmd'   { "$script:ThEsc[38;5;222m" }
        'note'  { "$script:ThEsc[38;5;244m" }
        'rule'  { "$script:ThEsc[38;5;238m" }
        'sub'   { "$script:ThEsc[38;5;150m" }
        'warn'  { "$script:ThEsc[38;5;209m" }
        'ok'    { "$script:ThEsc[38;5;114m" }
        'bold'  { "$script:ThEsc[1m" }
        'reset' { "$script:ThEsc[0m" }
        default { '' }
    }
}

function Write-ThHead([string]$Emoji, [string]$Title) {
    $b = ThPaint bold; $c = ThPaint title; $d = ThPaint rule; $r = ThPaint reset
    Write-Host ''
    Write-Host "$b$c$Emoji  $Title$r"
    Write-Host ("$d" + ('─' * 64) + "$r")
}

function Write-ThSub([string]$Emoji, [string]$Title) {
    $b = ThPaint bold; $s = ThPaint sub; $r = ThPaint reset
    Write-Host ''
    Write-Host "  $b$s$Emoji $Title$r"
}

function Write-ThRow([string]$Label, [string]$Command) {
    $l = ThPaint label; $c = ThPaint cmd; $r = ThPaint reset
    Write-Host ("  $l" + $Label.PadRight(24) + "$r $c$Command$r")
}

function Write-ThNote([string]$Text) {
    $n = ThPaint note; $r = ThPaint reset
    Write-Host ("  " + (' ' * 24) + " $n↳ $Text$r")
}

function Write-ThText([string]$Text) {
    $n = ThPaint note; $r = ThPaint reset
    Write-Host "  $n$Text$r"
}

function Write-ThWarn([string]$Text) {
    $w = ThPaint warn; $r = ThPaint reset
    Write-Host "  $w⚠  $Text$r"
}

function Write-ThOk([string]$Text) {
    $o = ThPaint ok; $r = ThPaint reset
    Write-Host "  $o✓  $Text$r"
}

function script:ThDefined([string]$Name) {
    [bool](Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue)
}

# --- ❓ the index ----------------------------------------------------------
function Show-TerminalHelp {
    Write-ThHead '🧰' "terminal-help v$script:ThVersion"
    Write-ThText 'A reference that lives in the shell. Every section is a command;'
    Write-ThText 'type its name to print it.'
    Write-Host ''
    Write-ThRow 'get_help'          '❓ this list'
    Write-ThRow 'get_versions'      '📋 what is installed on this machine'
    Write-Host ''
    Write-ThRow 'get_git_info'      '🌿 git — all three sections below'
    Write-ThRow '  get_git_branch_info'   '🌱 branch naming and commit messages'
    Write-ThRow '  get_git_worktree_info' '🌳 worktrees, and the rules that make them work'
    Write-ThRow '  get_git_pr_info'       '🔀 pull requests with gh'
    Write-Host ''
    Write-ThRow 'get_python_info'   '🐍 Python — with the two below'
    Write-ThRow '  get_uv_info'     '📦 uv: projects, dependencies, venvs'
    Write-ThRow '  get_uvicorn_info' '⚡ uvicorn and FastAPI launch lines'
    Write-Host ''
    Write-ThRow 'get_windows_info'  '🪟 Windows: PowerShell, winget, WSL, zsh'
    Write-ThRow 'get_mac_info'      '🍎 macOS: brew, shares, Finder'
    Write-ThRow 'get_linux_info'    '🐧 Linux: installing zsh, packages, services'
    Write-Host ''
    Show-UserHelpSections
    Show-UserHelp
}

# Sections that came from the user's own help directory.
function Show-UserHelpSections {
    if ($script:ThUserOrder.Count -eq 0) { return }
    Write-ThSub '🧩' "Yours (from $(Split-Path $script:ThUserHelpDir -Leaf))"
    foreach ($fn in $script:ThUserOrder) { Write-ThRow $fn $script:ThUserSections[$fn] }
}

function Show-UserHelp {
    $file = $script:ThUserFile
    $defined = @()
    if (ThDefined Show-UserInfo) { $defined += ,@('get_user_info', '🔒 your own reference sections') }
    $hasContent = (Test-Path $file) -and ((Get-Item $file).Length -gt 0)

    if ($defined.Count -gt 0 -or (ThDefined Invoke-UserOnLoad) -or $hasContent) {
        Write-ThSub '🔒' "Yours (from $(Split-Path $file -Leaf), never committed)"
        foreach ($d in $defined) { Write-ThRow $d[0] $d[1] }
        if ($defined.Count -eq 0) { Write-ThRow (Split-Path $file -Leaf) 'loaded — no hooks defined, which is fine' }
        if (ThDefined Invoke-UserOnLoad) { Write-ThNote 'Invoke-UserOnLoad runs on every new shell' }
    } else {
        Write-ThSub '🔒' 'Yours (empty for now)'
        Write-ThText 'Aliases, functions, environment variables, your own reference'
        Write-ThText 'sections — they go in your settings file, not in $PROFILE. It is'
        Write-ThText 'loaded on every shell, and an upgrade never touches it.'
        Write-ThRow 'Your settings file:' $file
        Write-ThRow 'What can go in it:'  "Get-Content `"$script:ThHome\powershell\profile-user.ps1.example`""
    }
}

# --- 🌿 git ----------------------------------------------------------------
function Show-GitInfo {
    Write-ThHead '🌿' 'Git'
    Write-ThRow 'Where am I:'       'git status -sb'
    Write-ThRow 'What changed:'     'git diff            (unstaged)'
    Write-ThRow ''                  'git diff --staged   (what a commit would contain)'
    Write-ThRow 'Stage and commit:' 'git add -A && git commit -m "feat: ..."'
    Write-ThNote 'in PowerShell 5.1 use ; instead of && between commands'
    Write-ThRow 'Undo last commit:' 'git reset --soft HEAD~1'
    Write-ThNote 'keeps the changes, drops the commit'
    Write-ThRow 'Sync with remote:' 'git fetch; git rebase origin/main'
    Write-ThRow 'Amend and repush:' 'git commit --amend; git push --force-with-lease'
    Write-ThNote '--force-with-lease, never --force: it refuses if someone pushed since your fetch'
    Write-Host ''
    Show-GitBranchInfo
    Show-GitWorktreeInfo
    Show-GitPrInfo
}

function Show-GitBranchInfo {
    Write-ThSub '🌱' 'Branches and commit messages'
    Write-ThRow 'Never commit to main.' 'every change is a branch, merged by a PR'
    Write-ThRow 'Branch format:'    '{type}/{kebab-case-slug}   (<= 6 words)'
    Write-ThRow 'Types:'            'feat/  fix/  hotfix/  docs/  chore/  refactor/'
    Write-ThRow 'Commit messages:'  'Conventional Commits — feat: fix: docs: chore:'
    Write-ThNote 'feat(share): retry the mount once on timeout'
    Write-ThRow 'List branches:'    'git branch -a --sort=-committerdate | Select-Object -First 10'
    Write-ThNote 'read this BEFORE starting: you may already have a branch for it'
}

function Show-GitWorktreeInfo {
    Write-ThSub '🌳' 'Worktrees — one feature, one branch, one worktree, one PR'
    Write-ThText 'A worktree is a second working directory sharing one .git. Two'
    Write-ThText 'features can be edited at once with no stashing and no branch'
    Write-ThText 'switching underneath live work.'
    Write-Host ''
    Write-ThRow 'Create:'           'git worktree add ../{repo}-{slug} -b feat/{slug}'
    Write-ThRow 'From a branch:'    'git worktree add ../{repo}-{slug} feat/{slug}'
    Write-ThRow 'Detached:'         'git worktree add --detach ../{repo}-check origin/main'
    Write-ThRow 'List:'             'git worktree list'
    Write-ThRow 'Remove when merged:' 'git worktree remove ../{repo}-{slug}'
    Write-ThRow ''                  'git branch -d feat/{slug}'
    Write-ThRow 'Prune stale entries:' 'git worktree prune'
    Write-Host ''
    Write-ThText 'The six rules that make it work:'
    Write-ThText '  1. Confirm where you are: git rev-parse --show-toplevel'
    Write-ThText '  2. Build, test and commit INSIDE the worktree.'
    Write-ThText '  3. A branch can be checked out in one worktree at a time.'
    Write-ThText '  4. node_modules and .venv are per-worktree — install again.'
    Write-ThText '  5. It isolates EDITING, not merge conflicts. Rebase first.'
    Write-ThText '  6. Remove it after the merge, or finished work looks live.'
}

function Show-GitPrInfo {
    Write-ThSub '🔀' 'Pull requests (gh)'
    Write-ThRow 'Install:'          'winget install --id GitHub.cli'
    Write-ThRow 'Sign in:'          'gh auth login'
    Write-ThRow 'Who am I:'         'gh api user -q .login'
    Write-ThNote 'the honest check — under the wrong account gh pr list prints'
    Write-ThNote 'nothing and exits 0, so an existing PR looks absent'
    Write-Host ''
    Write-ThText 'The loop:'
    Write-ThRow '  1. Branch:'      'git worktree add ../{repo}-{slug} -b feat/{slug}'
    Write-ThRow '  2. Commit:'      'git add -A; git commit -m "feat: ..."'
    Write-ThRow '  3. Push:'        'git push -u origin feat/{slug}'
    Write-ThRow '  4. Open:'        'gh pr create --fill'
    Write-ThRow '  5. Watch checks:' 'gh pr checks {n}'
    Write-ThRow ''                  'gh pr view {n} --json statusCheckRollup,mergeStateStatus'
    Write-ThNote 'pr view takes --json; older gh has no --json on pr checks'
    Write-ThRow '  6. Merge:'       'gh pr merge {n} --squash --delete-branch'
    Write-ThRow '  7. Clean up:'    'git worktree remove ../{repo}-{slug}'
    Write-Host ''
    Write-ThText 'Reading and reviewing:'
    Write-ThRow '  List open PRs:'  'gh pr list          (--author @me for yours)'
    Write-ThRow '  Read one:'       'gh pr view {n}      (--web to open a browser)'
    Write-ThRow '  Its diff:'       'gh pr diff {n}'
    Write-ThRow '  Check out:'      'gh pr checkout {n}'
    Write-ThRow '  Approve:'        'gh pr review {n} --approve'
}

# --- 🐍 python -------------------------------------------------------------
function Show-PythonInfo {
    Write-ThHead '🐍' 'Python'
    Write-ThRow 'Install Python:'   'winget install --id Python.Python.3.13'
    Write-ThRow 'Install uv:'       'winget install --id astral-sh.uv'
    Write-ThRow ''                  'powershell -c "irm https://astral.sh/uv/install.ps1 | iex"'
    Write-ThNote 'uv installs and manages Python itself, so the system Python'
    Write-ThNote 'does not have to be the right version — or exist at all'
    Write-Host ''
    Show-UvInfo
    Show-UvicornInfo
}

function Show-UvInfo {
    Write-ThSub '📦' 'uv'
    Write-ThRow 'New project:'      'uv init'
    Write-ThNote 'writes pyproject.toml and .python-version'
    Write-ThRow 'Add dependencies:' 'uv add "fastapi[standard]" uvicorn pytest'
    Write-ThRow 'Add dev deps:'     'uv add --dev pytest ruff mypy'
    Write-ThRow 'Install from lock:' 'uv sync'
    Write-ThRow 'Run in the venv:'  'uv run python app.py'
    Write-ThNote 'never activate a venv by hand'
    Write-ThRow 'Run a tool:'       'uvx ruff check .    (no project install)'
    Write-ThRow 'Manage interpreters:' 'uv python install 3.12 3.13'
    Write-ThRow ''                  'uv python pin 3.13'
}

function Show-UvicornInfo {
    Write-ThSub '⚡' 'Uvicorn'
    Write-ThRow 'What it is:'       'ASGI web server for Python'
    Write-ThRow 'Development:'      'uv run uvicorn app:app --reload --port 8000'
    Write-ThRow 'Production:'       'uv run uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4'
    Write-ThRow 'FastAPI shortcut:' 'uv run fastapi dev app.py'
}

# --- 🪟 windows ------------------------------------------------------------
function Show-WindowsInfo {
    Write-ThHead '🪟' 'Windows and PowerShell'
    Write-ThSub '🔷' 'PowerShell'
    Write-ThRow 'Install PowerShell 7:' 'winget install --id Microsoft.PowerShell'
    Write-ThNote "the built-in 'Windows PowerShell 5.1' is a different, older shell"
    Write-ThRow 'Your profile path:' '$PROFILE'
    Write-ThRow 'Create it:'        'New-Item -ItemType File -Path $PROFILE -Force'
    Write-ThRow 'Edit it:'          'notepad $PROFILE'
    Write-ThRow 'Reload it:'        '. $PROFILE'
    Write-ThRow 'Allow local scripts:' 'Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
    Write-ThNote 'without this a downloaded profile silently does not load'
    Write-ThSub '📦' 'winget and everyday commands'
    Write-ThRow 'Search / install:' 'winget search {name}   ·   winget install {id}'
    Write-ThRow 'Upgrade everything:' 'winget upgrade --all'
    Write-ThRow 'Clipboard:'        'Get-Content file | Set-Clipboard   ·   Get-Clipboard'
    Write-ThRow 'Find a command:'   'Get-Command {name}'
    Write-ThRow 'What holds a port:' 'Get-NetTCPConnection -LocalPort {port}'
    Write-ThRow 'Env var (session):' '$env:NAME = "value"'
    Write-ThRow 'Persist it:'       '[Environment]::SetEnvironmentVariable("NAME","v","User")'
    Write-ThSub '🐚' 'Getting zsh on Windows'
    Write-ThRow 'WSL (recommended):' 'wsl --install -d Ubuntu'
    Write-ThRow '  then, in WSL:'   'sudo apt install -y zsh; chsh -s $(which zsh)'
    Write-ThNote 'then run install.sh inside WSL for the zsh edition of this help'
    Write-ThRow 'MSYS2 instead:'    'pacman -S zsh'
    Write-ThNote 'Git for Windows ships bash, not zsh'
    Write-ThSub '🔁' 'WSL <-> Windows'
    Write-ThRow 'Windows files:'    '/mnt/c/Users/{you}      (from inside WSL)'
    Write-ThRow 'WSL files:'        '\\wsl$\Ubuntu\home\{you}  (from Explorer)'
    Write-ThNote 'keep projects on the WSL side — I/O across /mnt/c is far slower'
}

# --- 🍎 mac / 🐧 linux -----------------------------------------------------
function Show-MacInfo {
    Write-ThHead '🍎' 'macOS'
    Write-ThRow 'Install Homebrew:' '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    Write-ThNote 'on Apple silicon: eval "$(/opt/homebrew/bin/brew shellenv)"'
    Write-ThRow 'Install something:' 'brew install {formula}      (--cask for apps)'
    Write-ThRow 'Update everything:' 'brew update && brew upgrade'
    Write-ThRow 'Default shell:'    'chsh -s /bin/zsh'
    Write-ThNote 'zsh has been the default since Catalina'
    Write-ThRow 'Clipboard:'        'pbcopy   ·   pbpaste'
    Write-ThRow 'Mount a share:'    'mount_smbfs //{user}@{host}/{share} ~/{mount}'
    Write-ThRow 'Unmount:'          'diskutil unmount ~/{mount}'
    Write-ThRow 'Stop .DS_Store:'   'defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
}

function Show-LinuxInfo {
    Write-ThHead '🐧' 'Linux'
    Write-ThSub '🐚' 'Install zsh and make it the default'
    Write-ThRow 'Debian / Ubuntu:'  'sudo apt update && sudo apt install -y zsh'
    Write-ThRow 'Fedora / RHEL:'    'sudo dnf install -y zsh'
    Write-ThRow 'Arch:'             'sudo pacman -S zsh'
    Write-ThRow 'Alpine:'           'sudo apk add zsh'
    Write-ThRow 'Make it default:'  'chsh -s $(which zsh)'
    Write-ThNote 'log out and back in — chsh applies at the next login'
    Write-ThSub '⚙' 'Services and ports'
    Write-ThRow 'Service status:'   'systemctl status {unit}'
    Write-ThRow 'Logs:'             'journalctl -u {unit} -f --since "10 min ago"'
    Write-ThRow 'What holds a port:' 'ss -tulpn | grep {port}'
    Write-ThRow 'Disk and memory:'  'df -h    ·    free -h'
}

# --- 📋 versions -----------------------------------------------------------
function script:ThTool([string]$Exe, [string[]]$VersionArgs) {
    if (Get-Command $Exe -ErrorAction SilentlyContinue) {
        $out = & $Exe @VersionArgs 2>$null | Select-Object -First 1
        if ($out) { "$out" } else { 'installed' }
    } else { 'not installed' }
}

function Show-Versions {
    Write-ThHead '📋' 'Versions'
    Write-ThRow 'terminal-help:' "v$script:ThVersion"
    Write-ThRow 'OS:'            "$([Environment]::OSVersion.VersionString)"
    Write-ThRow 'PowerShell:'    "$($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    $py = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } else { 'python3' }
    Write-ThRow 'Python:'        (ThTool $py @('--version'))
    Write-ThRow 'uv:'            (ThTool 'uv' @('--version'))
    Write-ThRow 'git:'           (ThTool 'git' @('--version'))
    Write-ThRow 'gh:'            (ThTool 'gh' @('--version'))
    Write-ThRow 'node:'          (ThTool 'node' @('--version'))
    Write-ThRow 'WSL distros:'   (ThTool 'wsl' @('--list', '--quiet'))
}

# --- aliases: the same names as the zsh edition ----------------------------
Set-Alias -Name get_help              -Value Show-TerminalHelp   -Scope Global -Force
Set-Alias -Name help_me               -Value Show-TerminalHelp   -Scope Global -Force
Set-Alias -Name get_versions          -Value Show-Versions       -Scope Global -Force
Set-Alias -Name get_git_info          -Value Show-GitInfo        -Scope Global -Force
Set-Alias -Name get_git_branch_info   -Value Show-GitBranchInfo  -Scope Global -Force
Set-Alias -Name get_git_worktree_info -Value Show-GitWorktreeInfo -Scope Global -Force
Set-Alias -Name get_git_pr_info       -Value Show-GitPrInfo      -Scope Global -Force
Set-Alias -Name get_python_info       -Value Show-PythonInfo     -Scope Global -Force
Set-Alias -Name get_uv_info           -Value Show-UvInfo         -Scope Global -Force
Set-Alias -Name get_uvicorn_info      -Value Show-UvicornInfo    -Scope Global -Force
Set-Alias -Name get_windows_info      -Value Show-WindowsInfo    -Scope Global -Force
Set-Alias -Name get_mac_info          -Value Show-MacInfo        -Scope Global -Force
Set-Alias -Name get_linux_info        -Value Show-LinuxInfo      -Scope Global -Force

# --- your own help files ---------------------------------------------------
# Drop a *.help.ps1 file into profile-help.d beside your $PROFILE and it is
# loaded on every shell. The directory is yours: the installer creates it and
# never touches it again, so an upgrade cannot disturb what you put there.
#
# Dot-sourced at SCRIPT scope for the same reason as the settings file: `.`
# loads into the current scope, so doing this inside a function would trap the
# user's own functions there.
$script:ThUserHelpDir = if ($env:TH_USER_HELP_DIR) {
    $env:TH_USER_HELP_DIR
} elseif ($PROFILE) {
    Join-Path (Split-Path $PROFILE -Parent) 'profile-help.d'
} else {
    Join-Path $script:ThHome 'profile-help.d'
}

$script:ThUserSections = @{}     # function name -> description
$script:ThUserOrder    = @()

function Register-ThSection([string]$Function, [string]$Description) {
    if (-not $script:ThUserSections.ContainsKey($Function)) { $script:ThUserOrder += $Function }
    $script:ThUserSections[$Function] = $Description
}
Set-Alias -Name th_register -Value Register-ThSection -Scope Global -Force

if (Test-Path $script:ThUserHelpDir) {
    foreach ($f in (Get-ChildItem -Path $script:ThUserHelpDir -Filter '*.help.ps1' -File | Sort-Object Name)) {
        $before = @(Get-Command -CommandType Function -Name 'Show-*' -ErrorAction SilentlyContinue | ForEach-Object Name)
        . $f.FullName
        # A file that never calls th_register is still found, by diffing the
        # Show-* functions across the load — same rule as the zsh edition.
        foreach ($fn in @(Get-Command -CommandType Function -Name 'Show-*' -ErrorAction SilentlyContinue | ForEach-Object Name)) {
            if ($before -notcontains $fn) {
                if (-not $script:ThUserSections.ContainsKey($fn)) {
                    Register-ThSection $fn "📄 $($f.Name)"
                }
                # No auto-generated snake_case alias: mangling Show-DockerInfo
                # into a get_* name produced garbage, and PowerShell users type
                # the PowerShell name. Add your own Set-Alias if you want one.
            }
        }
    }
}

# --- the private half ------------------------------------------------------
# Your own settings live next to your $PROFILE as profile-user.ps1 — outside
# this repository. Resolved from $PROFILE rather than hardcoded, because the
# profile directory differs between Windows (Documents\PowerShell) and
# macOS/Linux pwsh (~/.config/powershell).
#
# This runs at SCRIPT scope on purpose, not inside a function. `.` sources into
# the CURRENT scope, so a function that dot-sourced this file would trap every
# function the user defines inside itself, and they would vanish the moment it
# returned. At script scope — with this file itself dot-sourced from $PROFILE —
# the user's definitions land in the global scope, where they belong.
$script:ThUserFile = if ($env:TH_USER_FILE) {
    $env:TH_USER_FILE
} elseif ($PROFILE) {
    Join-Path (Split-Path $PROFILE -Parent) 'profile-user.ps1'
} else {
    "$script:ThHome\powershell\user.ps1"
}

if (Test-Path $script:ThUserFile) { . $script:ThUserFile }

if (ThDefined Show-UserInfo) { Set-Alias -Name get_user_info -Value Show-UserInfo -Scope Global -Force }

# --- what a new shell prints -----------------------------------------------
# One line: the installed version, then whatever your own Invoke-UserOnLoad
# prints. Set TH_QUIET=1 to silence both.
if (-not $env:TH_QUIET) {
    $b = ThPaint bold; $c = ThPaint title; $n = ThPaint note; $m = ThPaint cmd; $r = ThPaint reset
    Write-Host "$b$c🧰 terminal-help$r ${b}v$($script:ThVersion)$r$n · $r${m}get_help$r"
    if (ThDefined Invoke-UserOnLoad) { Invoke-UserOnLoad }
}
