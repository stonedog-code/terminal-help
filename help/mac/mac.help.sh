#!/usr/bin/env zsh
# 🍎 macOS — Homebrew, the default shell, and the Finder settings worth changing.
# TH_TOPIC: mac
# TH_EMOJI: 🍎
# TH_DESC:  macOS — keys, the default shell, Finder, Homebrew
# TH_ALSO:  get_mac_keys_help | ⌨️ | moving the cursor: why Home is not Home

_th_help_mac() {
    th_head "🍎" "macOS"
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

    get_mac_keys_help

    # Homebrew is its own topic so it can be read on its own, but nobody
    # setting up a Mac wants to be told to go and find it.
    if th_defined get_homebrew_help; then
        get_homebrew_help
    else
        print -r --
        th_row "Homebrew:" "th_topics enable homebrew"
        th_note "brew has its own topic; it is not switched on"
    fi
}

get_mac_keys_help() {
    th_sub "⌨️" "Moving the cursor — Home is not Home here"
    th_text "On Windows, Home and End move the CARET to the start and end of the"
    th_text "line. On macOS they are historically SCROLL keys: in most apps they"
    th_text "jump the view to the top or bottom of the document and leave the"
    th_text "insertion point exactly where it was. That is the surprise, and it"
    th_text "is not a broken keyboard."
    print -r --
    th_text "In a text field, an editor, a browser box — anything but a terminal:"
    th_row "Start of line:"      "⌘ ←        (Command-Left)"
    th_row "End of line:"        "⌘ →"
    th_row "Start of document:"  "⌘ ↑"
    th_row "End of document:"    "⌘ ↓"
    th_row "Word left / right:"  "⌥ ←  ·  ⌥ →      (Option)"
    th_row "Select as you go:"   "add ⇧ to any of the above"
    th_note "on a keyboard with no Home/End at all, fn ← and fn → send them"
    print -r --
    th_text "In the terminal — zsh line editing, and these are the ones worth"
    th_text "learning because they work over ssh, in bash, and in most REPLs:"
    th_row "Start of line:"      "Ctrl-A"
    th_row "End of line:"        "Ctrl-E"
    th_row "Back / forward word:" "⌥ ←  ·  ⌥ →      (see the note below)"
    th_row "Delete to start:"    "Ctrl-U"
    th_row "Delete to end:"      "Ctrl-K"
    th_row "Delete word back:"   "Ctrl-W"
    th_row "Undo the edit:"      "Ctrl-_ "
    th_row "Search history:"     "Ctrl-R"
    th_row "Swap two characters:" "Ctrl-T"
    th_note "⌥ ← does nothing until the terminal sends a Meta key: Terminal.app"
    th_note "→ Settings → Profiles → Keyboard → \"Use Option as Meta key\";"
    th_note "iTerm2 → Profiles → Keys → Left Option key → Esc+"
    print -r --
    th_text "If Home and End do nothing at a zsh prompt (common over ssh, where"
    th_text "the terminfo entry and the escape codes disagree), bind them:"
    th_row "In ~/.zshrc-user.sh:" "bindkey \"^[[H\" beginning-of-line"
    th_row ""                    "bindkey \"^[[F\" end-of-line"
    th_note "find what your key actually sends with: cat -v, then press it"
    th_note "list every binding with: bindkey"
    print -r --
    th_text "VS Code is the exception that confuses everyone: it maps Home and"
    th_text "End to line start and end like Windows, so the same key behaves"
    th_text "differently in the editor and in the terminal panel beside it."
}
