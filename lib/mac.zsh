#!/usr/bin/env zsh
# 🍎 macOS — Homebrew, the default shell, and the Finder settings worth changing.

get_mac_info() {
    th_head "🍎" "macOS"
    th_row "Install Homebrew:"   "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    th_note "on Apple silicon it lands in /opt/homebrew — add it to PATH:"
    th_note "eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    th_row "Install something:"  "brew install {formula}      (--cask for apps)"
    th_row "Update everything:"  "brew update && brew upgrade"
    th_row "What is installed:"  "brew list --versions"
    print -r --
    th_row "Default shell:"      "chsh -s /bin/zsh"
    th_note "zsh has been the default since Catalina; nothing to install"
    th_row "OS version:"         "sw_vers"
    th_row "Software updates:"   "softwareupdate -l"
    print -r --
    th_row "Clipboard:"          "cat file | pbcopy     ·     pbpaste > file"
    th_row "Open in Finder:"     "open ."
    th_row "Open with TextEdit:" "open -e {file}"
    th_row "Quick Look:"         "qlmanage -p {file} 2>/dev/null"
    print -r --
    th_sub "🗂" "Finder"
    th_row "Stop .DS_Store:"     "defaults write com.apple.desktopservices \\"
    th_row ""                    "  DSDontWriteNetworkStores -bool true"
    th_note "Finder otherwise scatters .DS_Store and ._* files into every"
    th_note "network volume it opens, including project directories"
    th_row "Show hidden files:"  "defaults write com.apple.finder AppleShowAllFiles -bool true"
    th_row ""                    "killall Finder    (to apply either change)"
}
