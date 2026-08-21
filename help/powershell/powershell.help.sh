#!/usr/bin/env zsh
# TH_TOPIC: powershell
# TH_EMOJI: 🔷
# TH_DESC:  PowerShell — profile, execution policy, cmdlets, winget
# TH_ALSO:  get_powershell_profile_help | 📝 | the profile: where it is, why it silently does not load
# TH_ALSO:  get_powershell_cmdlets_help | 🧭 | the cmdlets worth knowing from a Unix shell

_th_help_powershell() {
    th_head "🔷" "PowerShell"
    th_text "Help for writing PowerShell, from a zsh prompt. terminal-help does"
    th_text "not run in PowerShell — this is a reference, not a port."
    print -r --
    th_row "Install PowerShell 7:" "winget install --id Microsoft.PowerShell"
    th_note "the built-in 'Windows PowerShell 5.1' is a different, older shell"
    th_note "and the two have separate profiles and module paths"
    th_row "Run one command:"    "pwsh -NoProfile -c \"Get-Date\""
    th_row "Which version:"      "\$PSVersionTable"
    th_row "Find a command:"     "Get-Command {name}"
    th_row "Read its docs:"      "Get-Help {cmdlet} -Examples"
    th_note "Get-Help is PowerShell's own; nothing to do with this tool"

    get_powershell_profile_help

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_powershell_cmdlets_help
}

get_powershell_profile_help() {
    th_sub "📝" "The profile"
    th_row "Its path:"           "\$PROFILE"
    th_note "Documents\\PowerShell on Windows, ~/.config/powershell on macOS"
    th_note "and Linux — never hardcode either; ask \$PROFILE"
    th_row "All four paths:"     "\$PROFILE | Format-List -Force"
    th_note "CurrentUserCurrentHost is the usual one; AllHosts also covers the ISE"
    th_row "Create it:"          "New-Item -ItemType File -Path \$PROFILE -Force"
    th_row "Reload it:"          ". \$PROFILE"
    th_row "Allow local scripts:" "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    th_note "without this a downloaded profile SILENTLY does not load, which"
    th_note "looks exactly like a broken profile rather than a policy"
    print -r --
    th_row "Dot-source scope:"   ". ./file.ps1   loads INTO the current scope"
    th_note "do it inside a function and the functions it defines are trapped"
    th_note "in that function and vanish when it returns — a classic half-hour"
}

get_powershell_cmdlets_help() {
    th_sub "🧭" "From a Unix shell"
    th_row "ls / find:"          "Get-ChildItem -Recurse -Filter *.log"
    th_row "cat:"                "Get-Content file -Tail 20 -Wait"
    th_row "grep:"               "Select-String -Pattern 'error' -Path *.log"
    th_row "which:"              "Get-Command {name}"
    th_row "ps / kill:"          "Get-Process pwsh    ·    Stop-Process -Name pwsh"
    th_row "curl:"               "Invoke-RestMethod https://api.example.com/x"
    th_note "already parses JSON — no jq step, the result is an object"
    th_row "jq:"                 "... | Select-Object -ExpandProperty items"
    th_row "clipboard:"          "Get-Content f | Set-Clipboard   ·   Get-Clipboard"
    th_row "env var (session):"  "\$env:NAME = \"value\""
    th_row "env var (persisted):" "[Environment]::SetEnvironmentVariable(\"NAME\",\"v\",\"User\")"
    th_row "What holds a port:"  "Get-NetTCPConnection -LocalPort {port}"
    print -r --
    th_note "Everything is an object, not text. Pipe into Get-Member to see"
    th_note "what you actually have: Get-Process | Get-Member"
}
