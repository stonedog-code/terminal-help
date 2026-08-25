#!/usr/bin/env zsh
# 🧪 playwright_python_pytest — running the suite, the fixtures pytest-playwright
# gives you, and the page-object shape that keeps it maintainable.
# TH_TOPIC: playwright_python_pytest
# TH_EMOJI: 🧪
# TH_DESC:  pytest-playwright — running, fixtures, page objects
# TH_RELATED: playwright_python
# TH_RELATED: pytest
# TH_ALSO:  get_playwright_python_pytest_pom_help | 🏗 | page objects, fixtures, parameterize

_th_help_playwright_python_pytest() {
    th_head "🧪" "pytest-playwright"

    th_text "pytest IS the runner — there is no second command to learn, and"
    th_text "-k, -x, markers, xdist and your conftest.py all keep working."
    print -r --

    th_sub "▶" "Running"
    th_row "Everything:"         "pytest"
    th_row "Watch it happen:"    "pytest --headed"
    th_row "…slowly:"            "pytest --headed --slowmo 500"
    th_row "One browser:"        "pytest --browser firefox"
    th_note "repeatable: --browser firefox --browser webkit runs both"
    th_row "In parallel:"        "pytest -n auto"
    th_note "needs pytest-xdist; each worker gets its own browser"
    th_row "Point at an env:"    "pytest --base-url http://localhost:8000"
    th_note "then page.goto(\"/login\") is relative to it"

    th_sub "🔍" "When it fails"
    th_row "Keep a trace:"       "pytest --tracing retain-on-failure"
    th_row "Open it:"            "playwright show-trace test-results/…/trace.zip"
    th_row "Video and shots:"    "pytest --video retain-on-failure --screenshot only-on-failure"
    th_note "all three land under test-results/ — the trace is the one that"
    th_note "actually tells you what happened"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🔧" "The fixtures you get for free"
    th_row "page"                "a fresh Page — function-scoped"
    th_row "context"             "a fresh BrowserContext — function-scoped"
    th_note "this is the isolation boundary: new cookies and storage per test,"
    th_note "which is why tests do not leak into each other"
    th_row "browser"             "session-scoped — launched once, so runs stay fast"
    th_row "browser_name"        "\"chromium\" | \"firefox\" | \"webkit\""
    th_row "playwright"          "the driver itself, session-scoped"
    print -r --
    th_text "Ask for one by naming it in the signature — nothing is imported:"
    th_row ""                    "def test_login(page): page.goto(\"/login\")"

    th_sub "⚙" "Changing how the browser starts"
    th_text "Override pytest-playwright's own fixtures by redeclaring them."
    th_row "Viewport, locale, auth:" "@pytest.fixture"
    th_row ""                    "def browser_context_args(browser_context_args):"
    th_row ""                    "    return {**browser_context_args,"
    th_row ""                    "        \"viewport\": {\"width\": 1280, \"height\": 800},"
    th_row ""                    "        \"storage_state\": \"auth.json\"}"
    th_note "storage_state is how a suite signs in ONCE — record it with"
    th_note "codegen --save-storage, then every test starts logged in"
    th_note "and a broken login page fails one test, not two hundred"
    th_row "Headed for one file:" "@pytest.mark.parametrize(\"browser_type_launch_args\","
    th_row ""                    "  [{\"headless\": False}], indirect=True)"

    th_sub "🪤" "Assert, do not sample"
    th_row "Retries until true:" "expect(rows).to_have_count(2)"
    th_row "Reads the DOM once:" "assert rows.count() == 2"
    th_note "the second is the classic flake — it samples while the page may"
    th_note "still be settling, and it fails on a slower machine than yours"
    th_row "Same for text:"      "expect(el).to_have_text(\"…\")  not  el.text_content()"
    th_row "Give one longer:"    "expect(el).to_be_visible(timeout=30_000)"
    print -r --
    th_text "There is no reason to sleep. Playwright already waits for an"
    th_text "element to be attached, visible, stable, enabled and unobscured"
    th_text "before every action, and expect() retries until it passes or"
    th_text "times out. Nearly every sleep people write re-implements that."

    get_playwright_python_pytest_pom_help
}

get_playwright_python_pytest_pom_help() {
    th_sub "🏗" "Page objects, fixtures, parameterize"
    th_text "A recorded test repeats its locators and hard-codes its values."
    th_text "Three moves fix it, and none of them are Playwright-specific."
    print -r --

    th_row "1. Locators in ONE place:" "class TodoPage(BasePage):"
    th_row ""                    "    @property"
    th_row ""                    "    def new_todo(self): return self.page.get_by_placeholder(…)"
    th_note "a property, not a field set in __init__ — both are lazy, but a"
    th_note "locator that takes an argument can only ever be a method, and"
    th_note "mixing the two forms makes a class half one thing, half the other"
    th_row "Parameterised one:"  "def item(self, title): return self.items.filter(has_text=title)"
    print -r --

    th_row "2. Actions assert they LANDED:" "def add(self, title) -> Self:"
    th_row ""                    "    self.new_todo.fill(title); self.new_todo.press(\"Enter\")"
    th_row ""                    "    expect(self.item(title)).to_be_visible()"
    th_row ""                    "    return self"
    th_note "a method may assert its own POSTCONDITION — proof the action"
    th_note "landed, the same for every caller. It may NOT assert the test's"
    th_note "expectation, which differs per test and is why the test exists"
    th_note "check_everything_is_fine() is the failure mode"
    print -r --

    th_row "3. A fixture builds it:" "@pytest.fixture"
    th_row ""                    "def todo_page(page: Page) -> TodoPage:"
    th_row ""                    "    return TodoPage(page).goto()"
    th_note "in conftest.py; the test asks for todo_page and gets a loaded"
    th_note "page object — navigation and readiness happen once, here"
    print -r --

    th_row "Then parameterize:"  "@pytest.mark.parametrize(\"title,want\", ["
    th_row ""                    "  pytest.param(\"buy milk\", \"1 item left\", id=\"single\"),"
    th_row ""                    "  pytest.param(\"<script>\", \"1 item left\", id=\"html\")])"
    th_note "id= is what makes a CI failure readable: it reports"
    th_note "test_count[html] rather than test_count[<script>-1 item left]"
    th_note "a loop inside one test stops at the first failure and reports one"
    th_note "result; parameterize gives you N results with N names"
}
