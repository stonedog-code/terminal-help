#!/usr/bin/env zsh
# 🐍 playwright_python — installing the Python binding, downloading browsers,
# and recording a test that pytest can actually collect.
# TH_TOPIC: playwright_python
# TH_EMOJI: 🐍
# TH_DESC:  Playwright for Python — install, browsers, codegen
# TH_RELATED: playwright
# TH_RELATED: playwright_python_pytest

_th_help_playwright_python() {
    th_head "🐍" "Playwright — Python"

    th_sub "📦" "Install"
    th_row "The test runner:"    "python -m pip install pytest"
    th_row "The binding:"        "python -m pip install pytest-playwright"
    th_note "pytest-playwright pulls in playwright itself — you do not install"
    th_note "both by hand"
    th_note "python -m pip, not bare pip: it uses the pip belonging to the"
    th_note "python you will run the tests with"
    th_row "With uv instead:"    "uv add --dev pytest-playwright"
    print -r --
    th_row "The browsers:"       "playwright install chromium"
    th_row ""                    "playwright install firefox"
    th_note "a separate step, and the one people miss — pip installs the"
    th_note "binding, never the browsers"
    th_row "Linux libraries too:" "playwright install --with-deps chromium"

    th_sub "🎥" "Record a test"
    th_row "Emit a pytest test:" "playwright codegen --target python-pytest \\"
    th_row ""                    "  -o tests/test_todo.py <url>"
    th_note "without --target you get a bare sync script with its own"
    th_note "browser launch, which pytest will not collect"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🔑" "Recording behind a login"
    th_row "Sign in once:"       "playwright codegen --save-storage=auth.json <url>"
    th_row "Reuse that session:" "playwright codegen --load-storage=auth.json <url>"
    th_note "otherwise every recording opens with the same twelve clicks"
    th_note "through a login form you were not trying to test"
    th_note "the same file feeds storage_state in a pytest fixture, so the"
    th_note "suite signs in once too — get_playwright_python_pytest_help"

    th_sub "🎯" "Better recordings"
    th_row "Your own test-id:"   "playwright codegen --test-id-attribute=data-qa <url>"
    th_note "emits get_by_test_id() instead of guessing at CSS"
    th_row "The async API:"      "playwright codegen --target python-async <url>"
    th_row "A device profile:"   "playwright codegen --device \"Pixel 7\" <url>"
    print -r --
    th_text "Add the test ids BEFORE you record. Ten minutes putting"
    th_text "data-testid on the handful of elements you are about to drive"
    th_text "turns codegen's output from something you rewrite into something"
    th_text "you mostly keep."
    print -r --
    th_text "The recorder's pick-locator button is worth opening even when you"
    th_text "are not recording: hover anything and it hands you a robust"
    th_text "locator. Watching it fail to find one is the clearest signal there"
    th_text "is that the markup needs a test id."

    th_sub "🧱" "Sync or async"
    th_row "Sync (the default):" "from playwright.sync_api import Page, expect"
    th_note "what pytest-playwright gives you, and what you want unless the"
    th_note "code under test is already async"
    th_row "Async:"              "from playwright.async_api import async_playwright"
    th_note "needs pytest-asyncio and async def tests; the API is otherwise"
    th_note "the same call for call"
    print -r --
    th_row "Python 3.11+ typing:" "def goto(self) -> Self:  # from typing import Self"
    th_note "below 3.11, typing_extensions.Self"

    th_sub "🪤" "Traps specific to the Python binding"
    th_row ".first is a PROPERTY:" "rows.first    not    rows.first()"
    th_note "the opposite of JavaScript, and the error is confusing:"
    th_note "'Locator' object is not callable"
    th_row "expect, not assert:"  "expect(loc).to_be_visible()  retries"
    th_note "assert loc.is_visible() reads the DOM once and is the classic"
    th_note "flake — see get_playwright_python_pytest_help"
    th_row "snake_case throughout:" "get_by_role, to_have_text, has_text="
    th_note "codegen gets this right; documentation you find in JS does not"
    th_row "Browsers are per-user:" "CI needs its own playwright install step"
    th_note "a cached pip install does not carry them"
}
