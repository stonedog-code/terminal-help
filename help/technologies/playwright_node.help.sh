#!/usr/bin/env zsh
# 🟢 playwright_node — the @playwright/test runner: scaffolding, running,
# projects and UI mode.
# TH_TOPIC: playwright_node
# TH_EMOJI: 🟢
# TH_DESC:  Playwright for Node — @playwright/test, projects, UI mode
# TH_RELATED: playwright

_th_help_playwright_node() {
    th_head "🟢" "Playwright — Node"

    th_sub "📦" "Install"
    th_row "Scaffold a suite:"   "npm init playwright@latest"
    th_note "writes playwright.config.ts, an example spec and a workflow —"
    th_note "more than npm i @playwright/test does on its own"
    th_row "Into an existing repo:" "npm i -D @playwright/test"
    th_row "The browsers:"       "npx playwright install chromium"
    th_row ""                    "npx playwright install firefox webkit"
    th_note "separate from npm ci, and not cached with node_modules"

    th_sub "▶" "Running"
    th_row "Everything:"         "npx playwright test"
    th_row "One project:"        "npx playwright test --project=chromium"
    th_row "One file / line:"    "npx playwright test tests/login.spec.ts:12"
    th_row "By title:"           "npx playwright test -g \"signs in\""
    th_row "Watch it happen:"    "npx playwright test --headed --debug"
    th_row "The UI mode:"        "npx playwright test --ui"
    th_note "the best way to work on a failing test: a time-travel view with"
    th_note "watch mode, no separate trace file to open"
    th_row "Last HTML report:"   "npx playwright show-report"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🔁" "Flakes and parallelism"
    th_row "Hunt a flake:"       "npx playwright test --repeat-each=20 -g \"the name\""
    th_row "Serialise it:"       "npx playwright test --workers=1"
    th_note "if it passes with one worker and fails with four, tests are"
    th_note "sharing data or a fixed port"
    th_row "Shard across CI:"    "npx playwright test --shard=1/4"
    th_row "Retry on CI only:"   "retries: process.env.CI ? 2 : 0  (in the config)"
    th_note "a test that passed on retry reports as FLAKY, not passed —"
    th_note "treat that colour as red"

    th_sub "🧱" "Config shapes worth knowing"
    th_row "Projects:"           "one per browser, device or auth state"
    th_row "A setup project:"    "{ name: 'setup', testMatch: /auth\\.setup\\.ts/ }"
    th_row "…depended on:"       "{ name: 'chromium', dependencies: ['setup'],"
    th_row ""                    "  use: { storageState: '.auth/user.json' } }"
    th_note "signs in once for the whole run; exactly one file drives the"
    th_note "login form — the one that is ABOUT the login form"
    th_row "Start the app first:" "webServer: { command: 'npm run dev', url: … }"
    th_note "let the server pick its port; a fixed one is a collision waiting"
    th_note "for a second worker"
    th_row "Fail on a stray only:" "forbidOnly: !!process.env.CI"
    th_note "a committed test.only silently skips the rest of the file, and"
    th_note "green is exactly what that looks like"

    th_sub "🪤" "Node-specific traps"
    th_row ".first() is a METHOD:" "rows.first()    not    rows.first"
    th_note "the opposite of the Python binding"
    th_row "A missing await:"    "expect() without await never fails"
    th_note "eslint-plugin-playwright's missing-playwright-await catches it;"
    th_note "without that rule the assertion is decorative"
    th_row "Register before acting:" "const p = page.waitForResponse(…)"
    th_row ""                    "await button.click(); await p"
    th_note "await the wait first and the response can land before anyone is"
    th_note "listening — a race you win locally and lose in CI"
}
