#!/usr/bin/env zsh
# 💬 stonedog-ask — ask-gemini and ask-copilot: install, credentials, scheduling.
# TH_TOPIC: stonedog_ask
# TH_EMOJI: 💬
# TH_DESC:  stonedog-ask — ask-gemini / ask-copilot: install, credentials, cron
# TH_RELATED: claude
# TH_ALSO:  get_stonedog_ask_cron_help | ⏰ | scheduling ask-copilot, and the interpreter that eats an evening

_th_help_stonedog_ask() {
    th_head "💬" "stonedog-ask"
    th_text "Command-line front ends for a second opinion — one command"
    th_text "per vendor, sharing one credential resolver and one usage"
    th_text "ledger. Wrappers around the vendor CLIs, not API clients, so"
    th_text "a subscription is used rather than a per-token key."

    th_sub "📍" "Where it lives"
    th_row "GitHub:"          "stonedog-code/stonedog-ask   (private)"
    th_note "a clone 404s without access — that is policy"
    th_row "npm:"             "nothing published — npm link the clone"

    th_sub "⚡" "Install and check"
    th_row "Put it on PATH:"  "npm link"
    th_row "Then both:"       "ask-gemini --check"
    th_row ""                 "ask-copilot --check"
    th_note "--check makes a REAL one-token call: a valid"
    th_note "credential is not an entitled one"

    th_sub "🧱" "Dependencies"
    th_row "Node:"            ">= 20"
    th_row "The vendor CLIs:" "@google/gemini-cli · @github/copilot"
    th_note "these wrap them; they do not replace them"

    th_sub "💡" "The tip that matters most"
    th_warn "Scope is the lever, not patience"
    th_text "A long, open-ended prompt hangs SILENTLY for 8+ minutes and"
    th_text "returns nothing; a short single question answers in 15-20"
    th_text "seconds. Ask one thing, name the file, cap the answer, and"
    th_text "give every call a timeout."

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🔷" "ask-gemini"
    th_row "A question:"      "ask-gemini \"does a UNION beat two rows?\""
    th_row "Review a PRD:"    "ask-gemini --review-prd docs/prd/x.md"
    th_row "Review a plan:"   "ask-gemini --review-plan docs/plan.md"
    th_row "Review a diff:"   "ask-gemini --review-diff origin/main"
    th_row "Whole repo:"      "ask-gemini --repo . \"where is auth enforced?\""
    th_row "Named files:"     "ask-gemini --file a.ts --file b.ts \"...\""
    th_note "the scope rule in the summary above is the whole"
    th_note "difference between 20 seconds and a dead call"

    th_sub "🧑‍✈️" "ask-copilot"
    th_row "Start of day:"    "ask-copilot --brief"
    th_row "End of day:"      "ask-copilot --wrap"
    th_row "One-off:"         "ask-copilot \"question\""
    th_row "Which sources:"   "ask-copilot --sources"
    th_note "it does not CREATE an MCP server — configure one"
    th_note "with copilot mcp add. It refuses to run without a"
    th_note "source you named, because a brief with a silently"
    th_note "missing source looks exactly like a quiet day."
    th_row "Journal:"         "~/.stonedog-ask/journal/    (one .md a day)"
    th_note "each run is given the recent entries back as"
    th_note "context — nothing in an inbox says \"you have"
    th_note "ignored me for four days\"; that fact lives only"
    th_note "in the gap between two summaries, so something has"
    th_note "to hold it"

    th_sub "🔑" "Credentials"
    th_text "Resolved through one shared module, first accepted wins:"
    th_row "1."               "the environment"
    th_row "2."               "AWS Secrets Manager, id from WS_SECRET_ID"
    th_note "consulted BEFORE any shell probe, deliberately: it"
    th_note "has to work in a session that never ran load-"
    th_note "secrets — which is every agent session and every"
    th_note "cron job"
    th_row "3."               "gh auth token, or a login-shell probe"
    th_warn "The losers are then STRIPPED, and that is the point"
    th_note "they are a precedence chain, so a stale value in"
    th_note "an earlier one silently beats a good value in a"
    th_note "later one. The symptom is \"I am not entitled\""
    th_note "and the cause is a variable some other tool"
    th_note "exported. Never fix a credential failure by"
    th_note "putting a key in a dotfile."

    th_sub "📊" "The ledger"
    th_row "Rows land in:"    "~/.claude/ai-usage/<vendor>.jsonl"
    th_row "Read it back:"    "get-gemini-usage   ·   get-claude-usage"
    th_warn "The two numbers are not the same KIND of number"
    th_note "Claude Code writes the API's own usage block, so"
    th_note "those counts were billed. Gemini reports no usage"
    th_note "metadata non-interactively, so its rows are a"
    th_note "4-chars-per-token estimate and every one carries"
    th_note "estimated: true."

    get_stonedog_ask_cron_help
}

get_stonedog_ask_cron_help() {
    th_sub "⏰" "Running it on a schedule"
    th_row "Print a schedule:" "ask-copilot --cron"
    th_note "linux on Linux, launchd on macOS; or say which:"
    th_row ""                 "ask-copilot --cron linux | systemd | macos"
    print -r --
    th_text "Before scheduling anything, in this order — each fails"
    th_text "differently, and finding out at 06:45 tomorrow is the"
    th_text "expensive way:"
    th_row "1."               "ask-copilot --check"
    th_row "2."               "ask-copilot --sources"
    th_row "3."               "ask-copilot --brief --dry-run"
    th_row "4."               "ask-copilot --brief        (one watched run)"

    th_sub "🪤" "The gotcha: the interpreter"
    th_warn "A scheduler's PATH is not your shell's PATH"
    th_note "the shebang is /usr/bin/env node and neither cron"
    th_note "nor launchd sources a profile, so under nvm the"
    th_note "job dies with \"env: node: No such file or"
    th_note "directory\" into a log nobody is watching —"
    th_note "indistinguishable from a quiet day, which is the"
    th_note "exact failure this tool exists to avoid"
    th_row "What cron gets:"  "env -i PATH=/usr/bin:/bin sh -c 'node -v'"
    th_note "--cron emits the ABSOLUTE directory of the"
    th_note "interpreter running it rather than hoping the"
    th_note "scheduler finds one"

    th_sub "🐧" "systemd user timers (preferred on a laptop)"
    th_row "Reload:"          "systemctl --user daemon-reload"
    th_row "Enable:"          "systemctl --user enable --now ask-copilot-brief.timer"
    th_row "Confirm:"         "systemctl --user list-timers 'ask-copilot-*'"
    th_row "Run this ONCE:"   "loginctl enable-linger \$USER"
    th_note "or user timers stop the moment you log out — the"
    th_note "single most common reason a user timer \"just"
    th_note "never runs\" Persistent=true also runs a missed"
    th_note "job once after boot; cron simply skips one whose"
    th_note "time passed while off"

    th_sub "🍎" "launchd, on macOS"
    th_row "Load:"            "launchctl bootstrap gui/\$(id -u) <plist>"
    th_row "Change one:"      "launchctl bootout gui/\$(id -u)/<label>"
    th_note "bootstrap on an already-loaded label fails"
    th_note "StartCalendarInterval takes an ARRAY of dicts and"
    th_note "launchd has no weekday range, so Mon-Fri is five"
    th_note "entries; Weekday is 0-6 with 0 = Sunday. A single"
    th_note "dict with a range quietly runs on Mondays only. If"
    th_note "the job reads protected data, grant Full Disk"
    th_note "Access to the binary in ProgramArguments — without"
    th_note "it the job runs, exits 0, and reads nothing."

    th_sub "🔍" "Confirming it actually ran"
    th_text "A scheduler exiting 0 is not evidence a brief was"
    th_text "produced. Check the artifact, not the exit code:"
    th_row "Did a file appear:" "ls -l ~/.stonedog-ask/journal/"
    th_row "What it said:"    "tail -40 ~/.stonedog-ask/journal/cron.log"
}
