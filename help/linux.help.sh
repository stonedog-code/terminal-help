#!/usr/bin/env zsh
# 🐧 Linux — installing zsh, package managers, services, ports.

th_register get_linux_info   "🐧 Linux: installing zsh, packages, services"

get_linux_info() {
    th_head "🐧" "Linux"
    th_sub "🐚" "Install zsh and make it the default"
    th_row "Debian / Ubuntu:"    "sudo apt update && sudo apt install -y zsh"
    th_row "Fedora / RHEL:"      "sudo dnf install -y zsh"
    th_row "Arch:"               "sudo pacman -S zsh"
    th_row "Alpine:"             "sudo apk add zsh"
    th_row "Make it default:"    "chsh -s \$(which zsh)"
    th_note "log out and back in — chsh applies at the next login, not now"
    th_row "Try it first:"       "exec zsh"
    th_row "Which shell am I:"   "echo \$0    ·    echo \$SHELL"
    th_note "\$0 is the running shell; \$SHELL is only the login default"
    print -r --
    th_sub "📦" "Packages"
    th_row "Search:"             "apt search {name}   ·   dnf search {name}"
    th_row "What owns a file:"   "dpkg -S {path}      ·   rpm -qf {path}"
    th_row "Install without root:" "apt-get download {pkg} && dpkg -x {pkg}.deb ~/local"
    th_note "extracts rather than installs — useful on a box with no sudo"
    print -r --
    th_sub "⚙" "Services and ports"
    th_row "Service status:"     "systemctl status {unit}"
    th_row "Start / enable:"     "sudo systemctl enable --now {unit}"
    th_row "Logs:"               "journalctl -u {unit} -f --since \"10 min ago\""
    th_row "What holds a port:"  "ss -tulpn | grep {port}"
    th_row "Disk and memory:"    "df -h    ·    free -h"
    th_row "What is eating CPU:" "top -o %CPU    ·    htop"
}
