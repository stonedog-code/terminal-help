#!/usr/bin/env zsh
# 🧪 pytest — running tests, narrowing to the one you care about, and the
# handful of ways a suite can look green while proving nothing.
# TH_TOPIC: pytest
# TH_EMOJI: 🧪
# TH_DESC:  pytest — running a subset, fixtures, and green-over-nothing
# TH_ALSO:  get_pytest_fixtures_help | 🔧 | fixtures, conftest.py and scope
# TH_ALSO:  get_pytest_traps_help | 🪤 | the ways a suite lies to you
# TH_RELATED: python

_th_help_pytest() {
    th_head "🧪" "pytest"
    th_row "Run everything:"     "uv run pytest"
    th_note "uv run, not a hand-activated venv — same rule as everywhere else"
    th_row "One file:"           "uv run pytest tests/test_views.py"
    th_row "One test:"           "uv run pytest tests/test_views.py::test_paging"
    th_row "One parametrised case:" "… ::test_summary_fits_one_page[git]"
    th_note "the [brackets] are part of the node id — quote it if your shell"
    th_note "does globbing, which zsh does"
    print -r --
    th_row "By name:"            "uv run pytest -k \"pager and not tty\""
    th_row "By marker:"          "uv run pytest -m slow    ·    -m \"not slow\""
    th_row "Stop at the first:"  "uv run pytest -x"
    th_row "Just the last failures:" "uv run pytest --lf"
    th_note "--lf reruns only what failed; --ff runs those first, then the rest"
    th_row "See what it collected:" "uv run pytest --collect-only -q"
    th_note "THE most useful flag here: it prints the size of the input set,"
    th_note "and a suite that collects fewer tests than yesterday is the"
    th_note "failure nobody notices"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🖨" "Seeing output"
    th_row "Show print/stdout:"  "uv run pytest -s"
    th_note "pytest captures output and shows it only for failures; -s turns"
    th_note "capture off entirely, which is what you want with a debugger"
    th_row "More detail:"        "uv run pytest -v    ·    -vv for full diffs"
    th_row "Less:"               "uv run pytest -q"
    th_row "Show slowest tests:" "uv run pytest --durations=10"
    th_row "Full traceback style:" "uv run pytest --tb=short  ·  --tb=line  ·  --tb=no"
    th_row "Drop into a debugger:" "uv run pytest --pdb"
    th_note "on the first failure, with the frame still alive"

    th_sub "⚙" "Configuration"
    th_row "Where it goes:"      "[tool.pytest.ini_options] in pyproject.toml"
    th_row "Always-on flags:"    "addopts = \"-q --strict-markers\""
    th_note "--strict-markers turns a typo'd @pytest.mark.slwo into an error"
    th_note "rather than a marker that silently matches nothing"
    th_row "Where tests live:"   "testpaths = [\"tests\"]"
    th_row "Declare a marker:"   "markers = [\"slow: takes more than a second\"]"
    th_row "Which config won:"   "uv run pytest --co -q 2>&1 | head -3"
    th_note "the header names the rootdir and configfile it actually used —"
    th_note "read it before believing a setting took effect"

    get_pytest_fixtures_help
    get_pytest_traps_help
}

get_pytest_fixtures_help() {
    th_sub "🔧" "Fixtures and conftest.py"
    th_row "Define one:"         "@pytest.fixture"
    th_row ""                    "def client(): return TestClient(app)"
    th_row "Use it:"             "def test_x(client): ..."
    th_note "the parameter name is the wiring — nothing is imported or passed"
    th_row "Share across files:" "put it in tests/conftest.py"
    th_note "conftest.py applies to its directory and everything below it, and"
    th_note "is imported automatically — never import it by name"
    th_row "Set-up and tear-down:" "yield inside the fixture; what follows the"
    th_row ""                    "yield runs after the test, pass or fail"
    print -r --
    th_row "Scope:"              "function (default) · class · module · session"
    th_note "session scope builds it once for the whole run — fast, and the"
    th_note "reason one test can leave state that breaks the next one"
    th_row "A temp directory:"   "def test_x(tmp_path): (tmp_path / \"a\").write_text(\"hi\")"
    th_note "tmp_path is a real pathlib.Path, cleaned up for you; prefer it to"
    th_note "writing anywhere near the repo"
    th_row "Capture output:"     "def test_x(capsys): out, err = capsys.readouterr()"
    th_row "Patch the environment:" "def test_x(monkeypatch): monkeypatch.setenv(\"K\", \"v\")"
    th_note "monkeypatch undoes itself at the end of the test; os.environ[...]"
    th_note "= by hand does not, and leaks into every test after it"
    print -r --
    th_row "Same test, many inputs:" "@pytest.mark.parametrize(\"n,want\", [(1,2), (2,4)])"
    th_row ""                    "def test_double(n, want): assert double(n) == want"
    th_note "each case is its OWN test with its own id, so one failing case"
    th_note "does not hide the others — much better than a loop inside a test"
    th_row "See the ids:"        "uv run pytest --collect-only -q"
}

get_pytest_traps_help() {
    th_sub "🪤" "The ways a suite lies to you"
    th_text "Every one of these reports success. That is what makes them"
    th_text "expensive: a red test gets fixed, a green one that checked nothing"
    th_text "gets trusted for months."
    print -r --
    th_row "A test with no assert:" "it passes by reaching the end"
    th_note "so does one whose assert is inside an if that never ran, and one"
    th_note "that asserts a Mock — a Mock is truthy and has every attribute"
    th_row "A typo'd marker:"    "-m slwo matches nothing and exits 0"
    th_note "--strict-markers is the fix; put it in addopts"
    th_row "A -k that matches nothing:" "\"no tests ran\" — and exit code 5, not 1"
    th_note "a CI step keyed on \"did it fail\" treats 5 as neither; key on == 0"
    th_row "A collect error in one file:" "the other files still run and can pass"
    th_note "read the collected COUNT, not just the last line"
    th_row "A skip you forgot:"  "@pytest.mark.skip left in after the fix landed"
    th_note "uv run pytest -rs lists every skip and why — read it sometimes"
    print -r --
    th_text "The habit that catches all of them: before believing a green run,"
    th_text "ask what set it examined. Print the count, compare it to the last"
    th_text "run, and prove the suite can fail by planting the defect it is"
    th_text "supposed to catch and watching a NAMED test go red."
    th_row "Plant, then check:"  "break the code on purpose, run, read the name"
    th_note "a guard that has only ever been observed passing has not been"
    th_note "tested — it has been run"
}
