#!/usr/bin/env zsh
# 🪟 Windows — PowerShell, winget, WSL, and getting zsh onto the machine.
# TH_TOPIC: windows
# TH_EMOJI: 🪟
# TH_DESC:  Windows — winget, WSL, and getting zsh onto the machine
# TH_RELATED: powershell

_th_help_windows() {
    th_head "🪟" "Windows and PowerShell"
    th_sub "🐚" "Two ways to get zsh on Windows"
    th_text "There is no native Windows zsh worth running. Pick one:"
    th_row "WSL (recommended):"  "wsl --install -d Ubuntu"
    th_note "a real Linux — then follow the 🐧 Linux section inside it"
    th_row "  then, in WSL:"     "sudo apt install -y zsh && chsh -s \$(which zsh)"
    th_row "Git Bash / MSYS2:"   "pacman -S zsh          (MSYS2 only)"
    th_note "Git for Windows ships bash, not zsh; MSYS2 can add zsh but the"
    th_note "PATH is a hybrid and Windows tools see different paths than it does"
    print -r --
    th_sub "📦" "winget and everyday commands"
    th_row "Search / install:"   "winget search {name}   ·   winget install {id}"
    th_row "Upgrade everything:" "winget upgrade --all"
    th_row "Clipboard:"          "Get-Content file | Set-Clipboard   ·   Get-Clipboard"
    th_row "Find a command:"     "Get-Command {name}"
    th_row "What holds a port:"  "Get-NetTCPConnection -LocalPort {port}"
    th_row "Environment var:"    "\$env:NAME = \"value\"        (this session)"
    th_row "Persist it:"         "[Environment]::SetEnvironmentVariable(\"NAME\",\"v\",\"User\")"
    print -r --
    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🔁" "WSL <-> Windows"
    th_row "Windows files:"      "/mnt/c/Users/{you}    (from inside WSL)"
    th_row "WSL files:"          "\\\\wsl\$\\Ubuntu\\home\\{you}  (from Explorer)"
    th_note "keep projects on the WSL side — I/O across /mnt/c is far slower"
    th_row "Run a Windows tool:" "explorer.exe .    ·    code ."
}
