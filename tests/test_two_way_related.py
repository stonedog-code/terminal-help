"""python and pytest name each other, and that is the first real mutual pair.

The cycle-safe path in `th_show_related` has had an assertion since NEH-1059,
but only against topics invented inside the test. A relationship people
actually read is a different thing to get wrong: it is the one that will be
edited, and a regression here shows up as a shell that prints a scary warning
during ordinary use.
"""

from __future__ import annotations

import pytest

from conftest import REPO


def _header(topic: str) -> str:
    # Match the header LINE, not a substring of it. `# TH_TOPIC: playwright`
    # is a substring of `# TH_TOPIC: playwright_python`, so an unanchored
    # search resolves a topic to whichever prefix-sharing file the glob
    # happened to yield first. Nothing caught it while every topic name was a
    # distinct word; the playwright family made three of them prefixes.
    def _declares(p) -> bool:
        return any(
            line.strip() == f"# TH_TOPIC: {topic}"
            for line in p.read_text().splitlines()[:20]
        )

    path = next(p for p in sorted(REPO.glob("help/*/*.help.sh")) if _declares(p))
    return path.read_text()


def test_the_pytest_topic_exists():
    assert "# TH_TOPIC: pytest" in _header("pytest")


@pytest.mark.parametrize("topic,names", [("python", "pytest"), ("pytest", "python")])
def test_the_relation_is_declared_in_both_directions(topic, names):
    """Declared, not merely rendered. A one-way TH_RELATED still produces a
    footer on one side, so reading the output alone cannot tell a mutual pair
    from a half-finished one."""
    assert f"# TH_RELATED: {names}" in _header(topic)


@pytest.mark.parametrize("topic,neighbour", [("python", "pytest"), ("pytest", "python")])
def test_each_names_the_other_by_default(run, topic, neighbour):
    r = run(f"get_{topic}_help")
    assert f"get_{neighbour}_help" in r


def test_related_pulls_in_the_pytest_summary(run):
    r = run("get_python_help --related")
    assert "uv run pytest -k" in r, "pytest's summary is missing"
    assert "--strict-markers" not in r, "pytest was expanded in FULL, not summarised"


def test_related_pulls_in_the_python_summary(run):
    r = run("get_pytest_help --related")
    assert "uv installs and manages Python itself" in r
    assert "Uvicorn" not in r, "python was expanded in FULL, not summarised"


@pytest.mark.parametrize("topic", ["python", "pytest"])
def test_the_mutual_pair_prints_each_side_once_and_quietly(run, topic):
    """Each side once, and no warning.

    Note what does the work here: expansion is ONE LEVEL, so the nested call
    never expands its own related topics and the pair cannot re-enter at all.
    The skip in `th_show_related` is not what keeps this quiet — that was the
    original belief, and a plant disproved it. The skip's own reachable case is
    the self-referential topic below."""
    r = run(f"get_{topic}_help --all")
    assert r.stdout.count("🧪  pytest") == 1
    assert r.stdout.count("🐍  Python") == 1
    assert "refusing to re-enter" not in r


def test_a_topic_that_lists_itself_is_skipped_quietly(run, tmp_path):
    """This is what the skip in `th_show_related` actually guards.

    Not the mutual pair — expansion is one level, so python/pytest can never
    re-enter each other and stay quiet without any help. Found by planting the
    removal of that skip and watching the whole suite still pass, which meant
    the line was covered by nothing and the comment above it was wrong.
    A topic naming itself IS reachable, and without the skip it prints the
    re-entrancy warning during ordinary use.
    """
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    (helpdir / "selfref.help.sh").write_text(
        "# TH_TOPIC: selfref\n# TH_DESC: lists itself\n# TH_RELATED: selfref\n"
        '_th_help_selfref() { th_row "S:" "SELF_BODY" }\n'
    )
    r = run("get_selfref_help --all", user_help_dir=helpdir)
    assert r.stdout.count("SELF_BODY") == 1
    assert "refusing to re-enter" not in r


def test_pytest_is_in_the_installer_default(run):
    """python ships selected by default and now names pytest. Shipping one half
    of a mutual pair leaves the other half reading `not loaded` for everyone
    who never chose topics — a worse first impression than one more default."""
    text = (REPO / "install.sh").read_text()
    assert "git|python|pytest)" in text
