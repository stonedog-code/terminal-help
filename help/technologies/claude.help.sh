#!/usr/bin/env zsh
# TH_TOPIC: claude
# TH_EMOJI: 🤖
# TH_DESC:  Claude Code — CLAUDE.md, settings, and the CLI
# TH_ALSO:  get_claude_files_help | 📁 | the files: CLAUDE.md, settings.json, and friends
# TH_ALSO:  get_claude_tips_help  | 💡 | what actually makes a session go well

_th_help_claude() {
    th_head "🤖" "Claude Code"
    th_row "Start it:"          "claude              (in the project directory)"
    th_row "One-shot, no TUI:"  "claude -p \"summarise the failing test\""
    th_note "-p prints and exits — the form to use in a script or a pipe"
    th_row "Pick up where you left off:" "claude --continue    ·    claude --resume"
    th_row "Update:"            "claude update"
    th_row "Health check:"      "claude doctor"
    print -r --
    th_row "In the session:"    "/help        every command"
    th_row ""                   "/init        write a CLAUDE.md for this repo"
    th_row ""                   "/clear       forget the conversation, keep the session"
    th_row ""                   "/compact     summarise it instead of forgetting"
    th_row ""                   "/model       switch model"
    th_row ""                   "/config      settings, including the theme"
    th_row ""                   "/permissions what it may do without asking"
    th_row ""                   "/agents      subagents"
    th_row ""                   "/mcp         MCP servers"
    print -r --
    th_row "Add to memory:"     "start a line with #  — it offers to write it to CLAUDE.md"
    th_row "Run a shell command:" "start a line with !  — output lands in the transcript"
    th_row "Reference a file:"  "@path/to/file    (tab-completes)"
    print -r --
    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_claude_files_help
    get_claude_tips_help
}

get_claude_files_help() {
    th_sub "📁" "The files"
    th_row "CLAUDE.md"          "instructions, loaded automatically"
    th_note "put it at the repo root; it is read every session, so it is the"
    th_note "cheapest place to record a convention you keep having to repeat"
    th_row "~/.claude/CLAUDE.md" "your instructions for EVERY project on this machine"
    th_note "machine-local: it does not travel to another box, a teammate, or"
    th_note "a cloud session. Anything that must travel belongs in the repo."
    th_row "CLAUDE.md nesting:" "a nested one loads when files under it are touched"
    th_note "so a monorepo can put package-specific rules beside the package"
    print -r --
    th_row ".claude/settings.json"       "project settings, committed"
    th_row ".claude/settings.local.json" "your overrides, gitignored"
    th_row "~/.claude/settings.json"     "your settings for every project"
    th_note "permissions, env vars and hooks live here — not in CLAUDE.md,"
    th_note "which is context the model reads rather than rules anything enforces"
    print -r --
    th_row ".claude/commands/*.md"  "your own /slash-commands"
    th_row ".claude/agents/*.md"    "subagent definitions (frontmatter + prompt)"
    th_row ".mcp.json"              "MCP servers shared with the repo"
    th_row ".claude/hooks/"         "scripts a hook can run"
    print -r --
    th_text "The distinction worth holding on to: CLAUDE.md is CONTEXT — it"
    th_text "persuades. A hook in settings.json is ENFORCEMENT — it refuses. If"
    th_text "a rule must never be broken, write the hook; a paragraph is a"
    th_text "request, and requests are occasionally not followed."
}

get_claude_tips_help() {
    th_sub "💡" "Tips"
    th_row "Plan first:"        "shift-tab cycles to plan mode"
    th_note "it reads and proposes without editing — the right mode for"
    th_note "anything you would want to review before it happens"
    th_row "Give it the error:"  "paste the whole failure, not a summary of it"
    th_note "a stack trace is data; \"it crashes\" is a hypothesis"
    th_row "Point at files:"    "@src/thing.ts is worth ten sentences of description"
    th_row "Keep sessions short:" "/clear at a task boundary"
    th_note "context is replayed every turn, so a long session costs more and"
    th_note "remembers things you have already superseded"
    th_row "Escape:"            "Esc interrupts; Esc Esc rewinds to an earlier turn"
    th_row "Multi-line input:"  "\\ then Enter, or option-Enter"
    print -r --
    th_text "Ask for the check, not just the change. \"Add the flag\" gets you a"
    th_text "flag; \"add the flag and show me it failing without it\" gets you"
    th_text "evidence, which is the part you were going to ask for anyway."
}
