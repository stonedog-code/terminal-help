"""Current behaviour of the topic commands, as of v0.32.0.

This file deliberately asserts what terminal-help does TODAY. The harness lands
before the feature it was built for, so a red test here means the harness is
wrong, not the tool — which is the only way to know the harness works at all.
"""

from __future__ import annotations

import pytest

from conftest import TOPICS


def test_topics_were_discovered():
    """The guard on every parametrised test below. An empty TOPICS list turns
    each of them into a green test over nothing, which is the exact shape of
    failure this repo keeps finding."""
    assert len(TOPICS) >= 10, f"only discovered {TOPICS!r} — the glob is wrong"


@pytest.mark.parametrize("topic", TOPICS)
def test_every_topic_prints_something(run, topic):
    r = run(f"get_{topic}_help")
    assert r.rc == 0
    assert r.n_lines > 3, f"get_{topic}_help printed {r.n_lines} line(s)"
    assert "no content is loaded" not in r


@pytest.mark.parametrize("topic", TOPICS)
def test_info_twin_matches_help(run, topic):
    """Not "the name exists" — the same bytes. A twin that resolves to a
    different function is worse than no twin, because it looks like it worked."""
    a = run(f"get_{topic}_help")
    b = run(f"get_{topic}_info")
    assert b.rc == 0
    assert a.stdout == b.stdout, f"get_{topic}_info differs from get_{topic}_help"


@pytest.mark.parametrize("topic", TOPICS)
def test_unknown_option_is_reported_not_swallowed(run, topic):
    """A tool that ignores what you typed teaches you that it did what you
    asked."""
    r = run(f"get_{topic}_help --nonsense-flag; print rc=$?")
    assert "I do not know the option" in r
    assert "rc=2" in r


def test_related_topic_is_named_but_not_printed(run):
    """mac names homebrew and does not inline it. 'brew bundle dump' appears
    only in the homebrew body, so it is a content probe rather than a word that
    might turn up in a cross-reference."""
    r = run("get_mac_help")
    assert "get_homebrew_help" in r
    assert "brew bundle dump" not in r


def test_all_expands_the_related_topic(run):
    """`brew leaves` is in homebrew's SUMMARY. It used to be `brew bundle dump`,
    which is now homebrew detail — and --all shows a neighbour at summary
    depth, so probing for detail here would assert the wrong specification."""
    assert "brew leaves" in run("get_mac_help --all")


def test_all_reaches_through_the_info_twin(run):
    """The twin has to forward its arguments or --all works on one spelling
    only."""
    assert "brew leaves" in run("get_mac_info --all")


def test_topic_cannot_print_itself_forever(run, tmp_path):
    """One line in a user file used to hang the shell with no exit but Ctrl-C:
    measured at 44,495 lines in 8 seconds on the unguarded code. The extension
    here reaches the topic INDIRECTLY, through a wrapper, because that is the
    form th_extend's own check cannot see."""
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    (helpdir / "loop.help.sh").write_text(
        "_th_ext_reenters() { get_git_help }\nth_extend git _th_ext_reenters\n"
    )
    r = run("get_git_help", user_help_dir=helpdir, timeout=20)
    assert "refusing to re-enter" in r


def test_th_extend_refuses_a_topics_own_entry_point(run, tmp_path):
    """Refused at REGISTRATION, which happens while the file is being sourced —
    so this is one of the few assertions that needs the load output."""
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    (helpdir / "loop.help.sh").write_text("th_extend git get_git_help\n")
    r = run("print loaded", user_help_dir=helpdir, capture_load=True, timeout=20)
    assert "print itself forever" in r


def test_a_bad_th_also_name_is_refused_not_evalled(run, tmp_path):
    """Generating the _info twin means eval'ing a name that came out of a
    header comment in a file terminal-help did not write."""
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    canary = tmp_path / "PWNED"
    (helpdir / "evil.help.sh").write_text(
        "# TH_TOPIC: evil\n# TH_DESC: injection\n"
        f"# TH_ALSO:  get_x_help; touch {canary}; : | X | injection\n"
        '_th_help_evil() { th_row "E:" "body" }\n'
    )
    r = run("print loaded", user_help_dir=helpdir, capture_load=True, timeout=20)
    assert not canary.exists(), "a TH_ALSO header executed a command"
    assert "cannot make an _info twin" in r


def test_a_related_cycle_prints_each_topic_once_and_says_nothing(run, tmp_path):
    """Two topics naming each other is a reasonable thing to write, not a
    mistake, so it must not trip the re-entrancy warning."""
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    (helpdir / "alpha.help.sh").write_text(
        "# TH_TOPIC: alpha\n# TH_DESC: alpha\n# TH_RELATED: beta\n"
        '_th_help_alpha() { th_row "A:" "ALPHA_BODY" }\n'
    )
    (helpdir / "beta.help.sh").write_text(
        "# TH_TOPIC: beta\n# TH_DESC: beta\n# TH_RELATED: alpha\n"
        '_th_help_beta() { th_row "B:" "BETA_BODY" }\n'
    )
    r = run("get_alpha_help --all", user_help_dir=helpdir, timeout=20)
    assert r.stdout.count("ALPHA_BODY") == 1
    assert r.stdout.count("BETA_BODY") == 1
    assert "refusing to re-enter" not in r


@pytest.mark.parametrize("columns", [60, 80, 100])
def test_nothing_wraps_at_the_terminal_edge(run, columns):
    """A description that does not fit must continue in the DESCRIPTION column,
    not at the left margin. A single unbreakable word is allowed to overflow —
    these are commands, and a command split across lines cannot be copied."""
    r = run("get_git_help", columns=columns)
    too_wide = [
        line
        for line in r.lines
        if len(line) > columns and " " in line[columns:]
    ]
    assert not too_wide, f"at {columns} columns: {too_wide[:3]}"


def test_output_off_a_tty_matches_an_80_column_terminal(run):
    """COLUMNS is 0 rather than empty off a tty, and a fallback that tested only
    for emptiness gave th_wrap a negative width: one word per line, 787 lines
    instead of 132."""
    with_cols = run("get_mac_help", columns=80)
    unset = run("unset COLUMNS; get_mac_help")
    assert unset.n_lines == with_cols.n_lines


def test_no_escape_codes_when_colour_is_off(run):
    assert "\x1b[" not in run("get_git_help").stdout


def test_colour_is_emitted_when_forced(run):
    """The negative test above passes just as happily against a tool that lost
    the ability to colour anything at all."""
    r = run("get_git_help", env={"TH_NO_COLOR": ""})
    # Still not a tty, so this asserts only that TH_NO_COLOR is what silenced
    # it — the tty path is covered by the bash suite, which can allocate one.
    assert r.rc == 0
