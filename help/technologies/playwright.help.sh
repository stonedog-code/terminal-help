#!/usr/bin/env zsh
# 🎭 playwright — the browser automation stack, and the parts that are the same
# whichever language binding you drive it from.
# TH_TOPIC: playwright
# TH_EMOJI: 🎭
# TH_DESC:  Playwright — browsers, codegen, traces; Node and Python below
# TH_RELATED: playwright_node
# TH_RELATED: playwright_python

_th_help_playwright() {
    th_head "🎭" "Playwright"

    th_text "One engine, several language bindings. The browsers, the recorder"
    th_text "and the trace viewer are shared; only the test runner differs."
    print -r --

    th_sub "📦" "Three separate things get installed"
    th_row "The binding:"        "npm i -D @playwright/test  ·  pip install pytest-playwright"
    th_row "The browsers:"       "playwright install chromium"
    th_note "NOT an npm or pip package — they live in a per-user cache outside"
    th_note "the project, which is why npm ci alone leaves you with a runner"
    th_note "and nothing to run it in"
    th_row "System libraries:"   "playwright install --with-deps chromium"
    th_note "Linux only — fonts, GTK, NSS, libasound"
    print -r --
    th_row "Named browsers:"     "playwright install chromium firefox webkit"
    th_row "Where they landed:"  "playwright install --dry-run"
    th_note "prints the cache path without downloading anything"

    th_sub "🚨" "The most common first-run failure"
    th_row "Executable doesn't exist at …" "you skipped playwright install"
    th_note "also what you get after upgrading the binding without re-running"
    th_note "it — the browser build is pinned to the binding version"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🎥" "Recording — the same tool in every language"
    th_row "Open the recorder:"  "playwright codegen <url>"
    th_row "Pick the output:"    "playwright codegen --target python-pytest <url>"
    th_note "targets: javascript, playwright-test, python, python-async,"
    th_note "python-pytest, csharp — the default is rarely the one you want"
    th_row "Your own test-id:"   "playwright codegen --test-id-attribute=data-qa <url>"
    th_note "nothing else on the command line improves the recording as much"
    th_row "Emulate a device:"   "playwright codegen --device \"iPhone 15\" <url>"
    print -r --
    th_text "Treat the output as a transcript, not a test: it records which"
    th_text "keys you pressed, not what behaviour you meant to guarantee."

    th_sub "🔍" "Traces — the reason to reach for this over the alternatives"
    th_row "Open one:"           "playwright show-trace trace.zip"
    th_row "No install at all:"  "https://trace.playwright.dev"
    th_note "drag a trace.zip onto that page — useful when the person who has"
    th_note "the failure is not the person who has the repo"
    th_text "A trace carries a DOM snapshot, the network log, console output"
    th_text "and a screenshot for every step, scrubbable like video."

    th_sub "🧭" "Which binding"
    th_row "Node / TypeScript:"  "get_playwright_node_help"
    th_note "@playwright/test — its own runner, fixtures, projects, UI mode"
    th_row "Python:"             "get_playwright_python_help"
    th_note "pytest-playwright — pytest IS the runner, so your fixtures,"
    th_note "plugins and -k all keep working"
}
