#!/usr/bin/env zsh
# 🧠 stonedog-mind — the daily quiz: install it, run it, and where a pack lives.
# TH_TOPIC: stonedog_mind
# TH_EMOJI: 🧠
# TH_DESC:  stonedog-mind — install, run, the gate, and where packs live
# TH_ALSO:  get_stonedog_mind_packs_help | 📚 | packs: where they are found, and what a valid one needs

_th_help_stonedog_mind() {
    th_head "🧠" "stonedog-mind"
    th_text "A daily, timeboxed, topic-driven quiz. An npm workspace: a"
    th_text "headless engine, a UI package, and a self-hostable web app."

    th_sub "📍" "Where it lives"
    th_row "GitHub:"          "stonedog-code/stonedog-mind    (public)"
    th_row "Clone:"           "gh repo clone stonedog-code/stonedog-mind"
    th_row "npm:"             "nothing is published"
    th_note "the root is private:true; @stonedogcode/mind-core,"
    th_note "-ui and -web are workspace-internal and resolve by"
    th_note "path"

    th_sub "⚡" "Install and run"
    th_row "Once:"            "npm install"
    th_row "Serve it:"        "npm run dev        # localhost:3210"
    th_note "that is the whole setup — no database, no account,"
    th_note "no import step; verified from a clean clone"
    th_row "The gate:"        "npm run gate"
    th_note "typecheck + tests + pack validation, in that order"

    th_sub "🧱" "Dependencies"
    th_row "Node:"            ">= 22.12, and it is a hard floor"
    th_note "Panda's CLI needs require(esm), unflagged from"
    th_note "22.12, and the tooling runs TypeScript directly"
    th_note "via --experimental-strip-types"
    th_row "Everything else:" "npm install    (no system packages)"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    get_stonedog_mind_packs_help

    th_sub "🗂" "The workspace"
    th_row "packages/core"   "@stonedogcode/mind-core — the engine"
    th_note "pure: session planning, grading, validation, item"
    th_note "identity. No React, no styling, no Node builtins."
    th_row "packages/ui"     "@stonedogcode/mind-ui — the quiz screens"
    th_row "apps/web"        "the standalone app, and the reference consumer"
    th_note "reading packs off disk lives behind a separate"
    th_note "entry point, mind-core/node, so a client component"
    th_note "that reaches for loadPacks gets a build error"
    th_note "rather than dragging node:fs into a browser bundle"

    th_sub "💾" "What it remembers, and where"
    th_row "The review log:"  "~/.stonedog-mind/reviews.jsonl"
    th_note "append-only, never edited; scheduling state is"
    th_note "DERIVED from it on read rather than stored beside"
    th_note "it"
    th_row "Move it:"         "STONEDOG_MIND_HOME"
    th_note "it lives outside the repo deliberately — it is a"
    th_note "record of what you keep getting wrong, and a"
    th_note "working tree is how that ends up in a commit"

    th_sub "💡" "Quick tips"
    th_row "Draft content:"   "npm run validate:draft"
    th_note "accepts generated items awaiting review; the"
    th_note "normal gate refuses provenance: generated with no"
    th_note "reviewed_by"
    th_row "Tests only:"      "npm test"
    th_warn "Two silent failures have guards — leave them in place"
    th_note "a Panda include glob that matches nothing renders"
    th_note "class names with no CSS behind them, and a missing"
    th_note "postcss.config.cjs emits no stylesheet at all."
    th_note "Neither produces a build error. panda.test.ts"
    th_note "reports how many files it found, which is the only"
    th_note "signal either way."
}

get_stonedog_mind_packs_help() {
    th_sub "📚" "Packs — where they are found"
    th_text "A quiz is a file. Resolution order, first match wins:"
    th_row "1."               "--packs <dir>"
    th_row "2."               "STONEDOG_MIND_PACKS      (colon-separated)"
    th_row "3."               "the nearest packs/ AND packs-private/"
    th_note "at or above the working directory"
    th_row "4."               "~/.stonedog-mind/packs"
    th_note "for a personal setup, drop .yaml files in that"
    th_note "last one — packs are read per request, so a new"
    th_note "file shows up on reload with no restart"

    th_sub "✅" "What the validator insists on"
    th_row "Mandatory:"       "license, source, and explain on every item"
    th_note "an item that cannot say why is not fit to teach"
    th_row "Types:"           "multiple-choice, true-false"
    th_note "cloze and free-text are deferred, not supported"
    th_row "Generated items:" "provenance: generated needs reviewed_by"
    th_note "and fails closed without it — no machine check can"
    th_note "decide whether a question has a single defensible"
    th_note "answer"
    th_row "General packs:"   "at least three difficulty: 1 warmups"
    print -r --
    th_text "Two content failures worth knowing, both found in this"
    th_text "repo's own packs on the gates' first run: 155 of 157"
    th_text "answers were written at index 0, so always picking A"
    th_text "would have scored ~100%; and 61 correct answers were the"
    th_text "longest option, because they carried a justifying clause"
    th_text "the distractors lacked. The justification goes in explain."
}
