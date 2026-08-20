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

Head "🧰 terminal-help v$Version"

# --- the profile -----------------------------------------------------------
$profilePath = $PROFILE.CurrentUserAllHosts
if (-not $profilePath) { $profilePath = $PROFILE }
$profileDir = Split-Path $profilePath -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

# Strip any previous block, keeping a backup. This is what makes re-running safe.
$lines = @(Get-Content $profilePath)
if ($lines -match [regex]::Escape($BeginMark)) {
    Copy-Item $profilePath "$profilePath.terminal-help.bak" -Force
    Note "backed up $(Split-Path $profilePath -Leaf) to $(Split-Path $profilePath -Leaf).terminal-help.bak"
    $kept = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $lines) {
        if ($line -like "*$BeginMark*") { $skip = $true; continue }
        if ($line -like "*$EndMark*")   { $skip = $false; continue }
        if (-not $skip) { $kept.Add($line) }
    }
    Set-Content -Path $profilePath -Value $kept -Encoding UTF8
}

if ($Uninstall) {
    Ok "removed the terminal-help block from $profilePath"
    Head '🏁 Done'
    Note 'the repository itself was not deleted'
    return
}

Add-Content -Path $profilePath -Encoding UTF8 -Value @(
    $BeginMark
    "`$env:TH_HOME = `"$ThHome`""
    '. "$env:TH_HOME\powershell\TerminalHelp.ps1"'
    $EndMark
)
Ok "added the terminal-help block to $profilePath"

# --- execution policy ------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Restricted', 'Undefined', 'AllSigned')) {
    Warn "your execution policy is '$policy' — the profile may refuse to load."
    Note 'fix it with: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
}

# --- the private half ------------------------------------------------------
Head '🔒 Your private half'
$userFile = "$ThHome\powershell\user.ps1"
if (Test-Path $userFile) {
    Ok 'user.ps1 already exists — left untouched'
} else {
    Say '  Connection details, hostnames and personal aliases live in user.ps1,'
    Say '  which is gitignored and never committed.'
    $reply = 'y'
    if (-not $Yes) {
        $reply = Read-Host '  Create user.ps1 from the example now? [Y/n]'
        if (-not $reply) { $reply = 'y' }
    }
    if ($reply -match '^[Yy]') {
        Copy-Item "$ThHome\powershell\user.ps1.example" $userFile
        Ok "created user.ps1 — edit it: notepad $userFile"
    } else {
        Note 'skipped. Copy it yourself: Copy-Item powershell\user.ps1.example powershell\user.ps1'
    }
}

Head '🏁 Done'
Ok "terminal-help v$Version installed from $ThHome"
Note 'open a new PowerShell, then type: get_help'
