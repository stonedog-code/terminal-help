#!/usr/bin/env zsh
# TH_TOPIC: copilot
# TH_EMOJI: 🧑‍✈️
# TH_DESC:  GitHub Copilot — instructions files, the CLI, chat in the editor
# TH_ALSO:  get_copilot_files_help | 📁 | instructions files and settings
# TH_ALSO:  get_copilot_cli_help   | ⌨️ | gh copilot, from the terminal

_th_help_copilot() {
    th_head "🧑‍✈️" "GitHub Copilot"
    th_text "Two products share the name: inline completion in the editor, and"
    th_text "Copilot Chat. The settings below are per-editor; the instructions"
    th_text "files are per-repository and apply to both."
    print -r --
    th_row "Accept a suggestion:" "Tab"
    th_row "Dismiss:"           "Esc"
    th_row "Next / previous:"   "⌥ ]   ·   ⌥ ["
    th_row "Ask for one:"       "⌥ \\"
    th_row "See them all:"      "⌃ ↩       (opens the suggestions pane)"
    th_note "on Windows and Linux those are Alt and Ctrl"
    print -r --
    th_row "Chat, inline:"      "⌘ I        (edit right where the cursor is)"
    th_row "Chat, panel:"       "⌃ ⌘ I"
    th_row "In chat:"           "/explain  /fix  /tests  /doc"
    th_row "Scope it:"          "@workspace   the repo    ·    @terminal   the last output"
    th_row ""                   "#file:src/app.ts   pin one file into the question"
    print -r --
    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_copilot_files_help
    get_copilot_cli_help
}

get_copilot_files_help() {
    th_sub "📁" "Instructions files"
    th_row ".github/copilot-instructions.md" "repo-wide instructions"
    th_note "committed, so it applies to everyone on the repo — the Copilot"
    th_note "equivalent of a CLAUDE.md at the root"
    th_row "What to put in it:" "conventions, the stack, what NOT to suggest"
    th_note "short and specific beats long and aspirational: it is prepended to"
    th_note "requests, so every wasted line is paid for on every request"
    print -r --
    th_row "VS Code settings.json:" "\"github.copilot.enable\": { \"*\": true, \"markdown\": false }"
    th_note "turn it off per language — most people want it off in markdown,"
    th_note "plain text and .env files"
    th_row "Enable instructions:" "\"github.copilot.chat.codeGeneration.useInstructionFiles\": true"
    th_row "Per-editor state:"   "the status bar icon toggles it for the session"
}

get_copilot_cli_help() {
    th_sub "⌨️" "From the terminal"
    th_row "Install:"           "gh extension install github/gh-copilot"
    th_row "Ask for a command:" "gh copilot suggest \"find files over 100MB\""
    th_row "Explain one:"       "gh copilot explain \"tar -xzf a.tgz -C /tmp\""
    th_note "explain is the one worth the keystrokes — it reads a command you"
    th_note "were about to paste from a search result"
    th_row "Update it:"         "gh extension upgrade gh-copilot"
    th_row "Auth:"              "gh auth login    (the CLI uses your gh account)"
    print -r --
    th_text "It suggests; it does not run anything. Copy the command out"
    th_text "yourself, which is the right amount of friction for something an"
    th_text "LLM just wrote about your filesystem."
}
