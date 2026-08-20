<#
    terminal-help installer, PowerShell edition.

        powershell -ExecutionPolicy Bypass -File .\powershell\install.ps1
        .\powershell\install.ps1 -Uninstall

    Adds ONE marked block to your existing $PROFILE. It never overwrites the
    profile, and re-running replaces its own block rather than appending
    another. The zsh side is install.sh, run from macOS, Linux or WSL.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$ThHome    = Split-Path $PSScriptRoot -Parent
$Version   = if (Test-Path "$ThHome\VERSION") { (Get-Content "$ThHome\VERSION" -Raw).Trim() } else { 'unknown' }
$BeginMark = '# >>> terminal-help >>>'
$EndMark   = '# <<< terminal-help <<<'

function Say($Text)  { Write-Host $Text }
function Ok($Text)   { Write-Host "  ✓  $Text" -ForegroundColor Green }
function Warn($Text) { Write-Host "  ⚠  $Text" -ForegroundColor Yellow }
function Note($Text) { Write-Host "  ↳  $Text" -ForegroundColor DarkGray }
function Head($Text) { Write-Host ''; Write-Host $Text -ForegroundColor Cyan }

# Strips any previous terminal-help block, keeping a backup. This is what makes
# re-running safe, and it must only ever run after the user has said yes.
function Remove-ThBlock([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $lines = @(Get-Content $Path)
    if (-not ($lines -match [regex]::Escape($BeginMark))) { return }
    Copy-Item $Path "$Path.terminal-help.bak" -Force
    Note "backed up $(Split-Path $Path -Leaf) to $(Split-Path $Path -Leaf).terminal-help.bak"
    $kept = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $lines) {
        if ($line -like "*$BeginMark*") { $skip = $true; continue }
        if ($line -like "*$EndMark*")   { $skip = $false; continue }
        if (-not $skip) { $kept.Add($line) }
    }
    Set-Content -Path $Path -Value $kept -Encoding UTF8
}

Head "🧰 terminal-help v$Version"

# --- the profile -----------------------------------------------------------
$profilePath = $PROFILE.CurrentUserAllHosts
if (-not $profilePath) { $profilePath = $PROFILE }
$profileDir = Split-Path $profilePath -Parent
$userFile   = Join-Path $profileDir 'profile-user.ps1'

function Confirm-Change([string]$Question) {
    if ($Yes -or [Console]::IsInputRedirected) { return $true }
    $reply = Read-Host "  $Question [Y/n]"
    return ($reply -notmatch '^[Nn]')
}

$block = @(
    $BeginMark
    '# Put YOUR PowerShell settings in profile-user.ps1 beside this file —'
    '# aliases, functions, and the Show-UserInfo / Invoke-UserOnLoad hooks.'
    '# NOT here: everything between these markers is rewritten by the installer.'
    "`$env:TH_HOME = `"$ThHome`""
    '. "$env:TH_HOME\powershell\TerminalHelp.ps1"   # the help, then your profile-user.ps1'
    $EndMark
)

if ($Uninstall) {
    if (Test-Path $profilePath) {
        Remove-ThBlock $profilePath
        Ok "removed the terminal-help block from $profilePath"
    }
    Note "$userFile was left alone — it is yours"
    Head '🏁 Done'
    Note 'the repository itself was not deleted'
    return
}

# Ask BEFORE changing anything: declining must leave the profile untouched.
if (-not (Confirm-Change "Update $profilePath so terminal-help loads in every PowerShell?")) {
    Note 'nothing was changed. To wire it up by hand, add this to $PROFILE:'
    Say ''
    $block | ForEach-Object { Say "    $_" }
    Say ''
    Note "then create $userFile for your own settings"
    Head '🏁 Done'
    return
}

if (-not (Test-Path $profileDir))  { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }
Remove-ThBlock $profilePath
Add-Content -Path $profilePath -Encoding UTF8 -Value $block
Ok "added the terminal-help block to $profilePath"

# --- execution policy ------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Restricted', 'Undefined', 'AllSigned')) {
    Warn "your execution policy is '$policy' — the profile may refuse to load."
    Note 'fix it with: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

# --- the private half ------------------------------------------------------
# profile-user.ps1 belongs to the user, not to this installer.
#
# Created when it is absent. Otherwise IGNORED — not read, not parsed, not
# copied, not backed up, not migrated. Whatever is in it is none of this
# script's business, which is what makes an upgrade safe to run blind.
Head '🔒 Your settings file'
if (Test-Path $userFile) {
    Ok "$(Split-Path $userFile -Leaf) already exists — ignored, it is yours"
} else {
    $seed = @(
        '<#'
        '    profile-user.ps1 — your PowerShell settings. This file is yours alone:'
        '    nothing installs into it, upgrades never touch it, and it is never'
        '    committed.'
        ''
        '    It is dot-sourced on every new shell by the terminal-help block in'
        '    $PROFILE. Put your settings HERE rather than in $PROFILE, which that'
        '    block rewrites.'
        ''
        '        aliases     Set-Alias -Name ll -Value Get-ChildItem -Scope Global'
        '        env vars    $env:EDITOR = "code"'
        ''
        '    terminal-help also calls these two functions if you define them:'
        ''
        '        Show-UserInfo     your own reference sections, printed on demand'
        '        Invoke-UserOnLoad runs on every new shell (the only thing that'
        '                          prints at startup besides the version line)'
        ''
        '    For a worked example of both, see profile-user.ps1.example in the'
        '    terminal-help clone.'
        '#>'
    )
    New-Item -ItemType File -Path $userFile -Force | Out-Null
    Set-Content -Path $userFile -Value $seed -Encoding UTF8
    Ok "created $(Split-Path $userFile -Leaf)"
    Note 'it is yours from here on — this installer never reads or writes it again'
}

Head '🏁 Done'
Ok "terminal-help v$Version installed from $ThHome"
Note 'open a new PowerShell, then type: get_help'
