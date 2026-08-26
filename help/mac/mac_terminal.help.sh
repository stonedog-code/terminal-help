#!/usr/bin/env zsh
# 🖥 Terminal.app — tabs, titles, panes and the Finder integration. The app
# macOS ships, not iTerm2 and not this tool.
# TH_TOPIC: mac_terminal
# TH_EMOJI: 🖥
# TH_DESC:  Terminal.app — tabs, titles, panes, marks, Finder integration
# TH_RELATED: mac
# TH_ALSO:  get_mac_terminal_title_help | 🏷 | naming a tab from a script, and what overwrites it

_th_help_mac_terminal() {
    th_head "🖥" "Terminal.app"
    th_text "The terminal macOS ships with. Everything here is the APP —"
    th_text "its windows, tabs and menus — not the shell running inside it."

    th_sub "🗂" "Tabs and windows"
    th_row "New tab:"          "⌘T"
    th_row "New window:"       "⌘N"
    th_note "both open the profile marked Default; ⌘⇧T and"
    th_note "⌘⇧N let you pick a different one first"
    th_row "Next / previous:"  "⌘⇧]  /  ⌘⇧[      (also ⌃Tab)"
    th_row "Jump to a tab:"    "⌘1 … ⌘9"
    th_row "Close tab:"        "⌘W          (window: ⌘⇧W)"
    th_row "Move a tab out:"   "drag it off the tab bar"
    th_note "and back onto another window's bar to merge it in;"
    th_note "Window ▸ Merge All Windows collects the strays"

    th_sub "🏷" "Naming a tab"
    th_row "By hand:"          "Shell ▸ Show Inspector  (⌘I)"
    th_note "the Info pane's Name field renames THIS tab; it"
    th_note "sticks until something else sets a title"
    th_row "From the shell:"   "printf '\\e]0;%s\\a' \"my title\""
    th_note "OSC 0 sets the tab and the window at once — this"
    th_note "is the one to use in a script or a function"
    th_warn "A tab that renames itself back is the profile"
    th_note "Settings ▸ Profiles ▸ Window ▸ Title composes the"
    th_note "title from the active process and the folder, and"
    th_note "those parts reappear. Clear the checkboxes."

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_mac_terminal_title_help

    th_sub "🪟" "Panes, and finding things in the scrollback"
    th_row "Split the pane:"   "⌘D          (close it: ⌘⇧D)"
    th_note "one shell, two views of its scrollback — not two"
    th_note "shells, which is what tmux gives you"
    th_row "Find:"             "⌘F     ·     again: ⌘G  /  ⌘⇧G"
    th_row "Clear scrollback:" "⌘K"
    th_note "⌃L only clears the SCREEN; ⌘K discards the buffer"
    th_row "Between prompts:"  "⌘↑  /  ⌘↓"
    th_note "Terminal marks each prompt automatically, so these"
    th_note "jump command by command. Edit ▸ Marks has the rest,"
    th_note "including selecting everything between two marks."
    th_row "Bigger / smaller:" "⌘+  ·  ⌘-  ·  reset ⌘0"

    th_sub "🖱" "Things the mouse does that are worth knowing"
    th_row "Position the cursor:" "⌥-click anywhere on the line"
    th_note "moves the shell's cursor there, no arrow keys"
    th_row "Open a path or URL:" "⌘-double-click it"
    th_row "Paste a file's path:" "drag the file into the window"
    th_note "quoted correctly, spaces and all"
    th_row "Selection is a menu:" "right-click a selected path"

    th_sub "📋" "The clipboard, from the shell"
    th_row "Copy:"             "pbcopy < file      ·     cmd | pbcopy"
    th_row "Paste:"            "pbpaste > file"
    th_note "macOS commands, not Terminal's — over ssh they"
    th_note "act on the REMOTE clipboard, not yours"

    th_sub "📁" "Finder, both directions"
    th_row "Open a folder here:" "open ."
    th_row "Open one in Terminal:" "open -a Terminal ~/some/dir"
    th_row "From a Finder window:" "right-click ▸ Services ▸ New Terminal"
    th_note "off by default: turn it on in Settings ▸ Keyboard ▸"
    th_note "Keyboard Shortcuts ▸ Services ▸ Files and Folders"

    th_sub "⚙️" "Profiles, and getting a set of tabs back"
    th_row "Settings:"         "⌘,"
    th_row "Share a profile:"  "Profiles ▸ ⚙ ▸ Export…   (a .terminal file)"
    th_note "double-clicking one imports it on another Mac"
    th_row "Save a layout:"    "Window ▸ Save Windows as Group…"
    th_note "every window, tab, size and working directory —"
    th_note "the feature people switch terminals to get"
    th_row "Reopen on launch:" "Settings ▸ Startup ▸ open window group"

    th_sub "🤖" "Driving it from a script"
    th_row "New window + command:" "osascript -e 'tell app \"Terminal\" to"
    th_row ""                 "  do script \"uptime\"'"
    th_warn "do script opens a WINDOW; there is no tab verb"
    th_note "a new tab needs System Events to press ⌘T, which"
    th_note "requires Automation permission and breaks whenever"
    th_note "the app is not frontmost. Use windows instead."
    th_row "Am I in Terminal.app:" "[[ \$TERM_PROGRAM == Apple_Terminal ]]"
    th_note "the same test /etc/zshrc makes before adding"
    th_note "its own working-directory hook"
}

get_mac_terminal_title_help() {
    th_sub "🏷" "Titles, properly"
    th_text "Three escape sequences, and they are not the same one:"
    th_row "Tab and window:"   "printf '\\e]0;%s\\a' \"\$1\""
    th_row "Tab only:"         "printf '\\e]1;%s\\a' \"\$1\""
    th_row "Window only:"      "printf '\\e]2;%s\\a' \"\$1\""
    th_note "\\a terminates it. Everything between the ; and"
    th_note "that is the title, taken literally."
    print -r --
    th_text "As a function, in ~/.zshrc-user.sh:"
    th_row "  " "title() { printf '\\e]0;%s\\a' \"\$*\" }"
    th_note "then: title \"prod tail\"  ·  title \"\$PWD:t\""

    th_sub "🔁" "Why it does not stick"
    th_text "A title set once is overwritten by whatever sets one"
    th_text "next, and on a stock Mac two things do:"
    th_row "The profile:"      "Settings ▸ Profiles ▸ Window ▸ Title"
    th_note "its checkboxes compose a title from the active"
    th_note "process, the folder and the shell. Clear them"
    th_note "all and yours is the only title in play."
    th_row "A precmd hook:"    "anything that retitles at each prompt"
    th_note "macOS ships one in /etc/zshrc reporting the cwd."
    th_note "That is OSC 7, and it is what makes ⌘T open the"
    th_note "new tab in the SAME folder — worth keeping."
    print -r --
    th_text "So set the title from a precmd of your own if you want"
    th_text "it computed, and from a plain function if you want it"
    th_text "to stay put until you change it."
}
