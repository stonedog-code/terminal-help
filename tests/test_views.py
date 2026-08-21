"""The four views, the flags that select them, and the pager.

A topic prints a summary by default. Two independent switches widen it: how
much of THIS topic (`--detailed`), and how much of its neighbours
(`--related`). `--all` is both, which is why it must be byte-identical to
`--detailed --related` — that equality is asserted rather than assumed, because
a third code path pretending to be a combination is exactly where the two drift.
"""

from __future__ import annotations

import pytest

from conftest import TOPICS

# One page at the size the whole tool is written for. The number is the promise:
# a summary that needs scrolling is not a summary.
PAGE_ROWS = 40
PAGE_COLS = 80


def _detail_topics() -> list[str]:
    """Topics that actually declare a cut. A topic whose content already fits
    one page has no detailed view, and must not be offered one."""
    from conftest import REPO

    out = []
    for path in sorted(REPO.glob("help/*/*.help.sh")):
        text = path.read_text()
        if "\n    th_detail || return" not in text:
            continue
        for line in text.splitlines()[:20]:
            if line.startswith("# TH_TOPIC:"):
                out.append(line.split(":", 1)[1].strip())
                break
    return out


DETAIL_TOPICS = _detail_topics()
FLAT_TOPICS = [t for t in TOPICS if t not in DETAIL_TOPICS]


def test_the_split_was_discovered():
    """Guards every parametrisation below. If the marker string ever changes,
    DETAIL_TOPICS silently empties and a dozen tests go green over nothing."""
    assert len(DETAIL_TOPICS) >= 8, f"only found cuts in {DETAIL_TOPICS!r}"
    assert FLAT_TOPICS, "no topic fits one page — the probe is wrong"


@pytest.mark.parametrize("topic", DETAIL_TOPICS)
def test_the_cut_is_inside_the_topic_body(topic):
    """The guard belongs in `_th_help_<topic>`, not in a TH_ALSO sub-function.

    Both placements LOOK right — a guard at the top of a sub-function also
    hides it from the summary — and two of the nine landed there on the first
    attempt. What it actually does is different: it truncates that one
    sub-section rather than the topic, so a second sub-function below it still
    prints, and the summary stops being a prefix of the detailed view. That is
    how it was found (test_detailed_is_strictly_more_than_summary went red on
    powershell), but the failure was three steps from the cause, so this
    asserts the cause directly.
    """
    from conftest import REPO

    path = next(
        p for p in REPO.glob("help/*/*.help.sh")
        if f"# TH_TOPIC: {topic}" in p.read_text()
    )
    enclosing = None
    for line in path.read_text().splitlines():
        stripped = line.rstrip()
        if stripped.endswith("() {") and not stripped.startswith(" "):
            enclosing = stripped.split("(")[0]
        if line.strip().startswith("th_detail || return"):
            break
    assert enclosing == f"_th_help_{topic}", (
        f"{path.name}: the th_detail guard is inside {enclosing}(), "
        f"not in _th_help_{topic}()"
    )


# --- the headline promise ---------------------------------------------------


@pytest.mark.parametrize("topic", TOPICS)
def test_summary_fits_one_page(run, topic):
    """The whole point. Measured at 80x40, including the related-topics footer
    and the hint about --detailed, because the reader's screen includes them."""
    r = run(f"get_{topic}_help", columns=PAGE_COLS, lines=PAGE_ROWS)
    assert r.n_lines <= PAGE_ROWS, (
        f"get_{topic}_help is {r.n_lines} lines at {PAGE_COLS}x{PAGE_ROWS}; "
        f"move the `th_detail || return` guard earlier in its body"
    )


@pytest.mark.parametrize("topic", DETAIL_TOPICS)
def test_detailed_is_strictly_more_than_summary(run, topic):
    """And the summary is a PREFIX of it, not merely shorter. That is what the
    single-body-with-a-cut design buys: the two views cannot disagree about the
    content they share, because it is the same lines."""
    summary = run(f"get_{topic}_help")
    detailed = run(f"get_{topic}_help --detailed")
    assert detailed.n_lines > summary.n_lines

    # Compare the BODIES. Both views end with the same related-topics footer,
    # so the summary is not a literal prefix of the detailed output — it is a
    # prefix of everything above that footer, which is the part the cut governs.
    def body(result):
        out = []
        for line in result.lines:
            if "🔗 Related topics" in line:
                break
            if "--detailed for the rest" in line:
                continue
            out.append(line)
        # The summary emits a blank line to separate that hint from the content
        # above it; the detailed view has no hint and so no separator. Trailing
        # blanks are presentation, not content, and comparing them makes this
        # assert layout rather than the thing it is for.
        while out and not out[-1].strip():
            out.pop()
        return out

    head = body(summary)
    assert head, "the summary has no body at all"
    assert body(detailed)[: len(head)] == head


# --- the flag matrix --------------------------------------------------------


def test_all_is_exactly_detailed_plus_related(run):
    """Not "similar" — the same bytes. --all is a spelling of two switches, and
    the moment it becomes its own code path the three views start to drift."""
    combined = run("get_mac_help --detailed --related")
    alias = run("get_mac_help --all")
    assert combined.stdout == alias.stdout


def test_default_shows_this_topic_only_and_names_the_rest(run):
    r = run("get_mac_help")
    assert "Stop .DS_Store" in r  # macOS summary content
    assert "Moving the cursor" not in r  # macOS detail
    assert "brew leaves" not in r  # homebrew summary
    assert "get_homebrew_help" in r  # ...but it is NAMED


def test_detailed_adds_this_topic_only(run):
    r = run("get_mac_help --detailed")
    assert "Moving the cursor" in r
    assert "brew leaves" not in r


def test_related_adds_neighbours_at_summary_depth(run):
    r = run("get_mac_help --related")
    assert "Moving the cursor" not in r, "--related must not deepen THIS topic"
    assert "brew leaves" in r, "the related topic's summary is missing"
    assert "Reproducing a machine" not in r, "the related topic was printed in FULL"


def test_all_is_detailed_here_and_summary_there(run):
    """The asymmetry is the whole specification of --all, and it is the thing
    most likely to be quietly implemented as detail-everywhere."""
    r = run("get_mac_help --all")
    assert "Moving the cursor" in r  # this topic, in detail
    assert "brew leaves" in r  # the neighbour, in summary
    assert "Reproducing a machine" not in r  # ...and NOT in detail


def test_related_expansion_is_one_level_only(run, tmp_path):
    """a -> b -> c. Asking about `a` must not walk the whole graph: that is the
    complaint that started this work, one topic printing as the whole manual."""
    helpdir = tmp_path / "help"
    helpdir.mkdir()
    for name, rel in (("aaa", "bbb"), ("bbb", "ccc"), ("ccc", "")):
        rel_line = f"# TH_RELATED: {rel}\n" if rel else ""
        (helpdir / f"{name}.help.sh").write_text(
            f"# TH_TOPIC: {name}\n# TH_DESC: {name}\n{rel_line}"
            f'_th_help_{name}() {{ th_row "X:" "BODY_{name.upper()}" }}\n'
        )
    r = run("get_aaa_help --all", user_help_dir=helpdir)
    assert "BODY_AAA" in r
    assert "BODY_BBB" in r
    assert "BODY_CCC" not in r, "--all walked past the immediate neighbours"


@pytest.mark.parametrize("flag", ["", "--detailed", "--related", "--all", "--help"])
def test_info_twin_accepts_every_flag_identically(run, flag):
    a = run(f"get_mac_help {flag}")
    b = run(f"get_mac_info {flag}")
    assert a.rc == b.rc == 0
    assert a.stdout == b.stdout


@pytest.mark.parametrize("short,long", [("-d", "--detailed"), ("-r", "--related"),
                                        ("-a", "--all"), ("-h", "--help")])
def test_short_flags_match_their_long_forms(run, short, long):
    assert run(f"get_mac_help {short}").stdout == run(f"get_mac_help {long}").stdout


# --- --help -----------------------------------------------------------------


@pytest.mark.parametrize("topic", TOPICS)
def test_help_names_every_flag(run, topic):
    """Every flag, on every topic. A flag documented in the README and missing
    from --help is a flag nobody at a prompt will ever find."""
    r = run(f"get_{topic}_help --help")
    assert r.rc == 0
    for flag in ("--detailed", "--related", "--all", "--help"):
        assert flag in r, f"get_{topic}_help --help does not mention {flag}"
    assert f"get_{topic}_info" in r, "the _info spelling is not mentioned"


def test_help_names_the_related_topics(run):
    assert "homebrew" in run("get_mac_help --help")


def test_help_says_so_when_there_are_no_related_topics(run):
    """Silence would read as a rendering bug rather than as an answer."""
    r = run("get_linux_help --help")
    assert "none" in r


@pytest.mark.parametrize("topic", TOPICS)
def test_unknown_option_points_at_help(run, topic):
    r = run(f"get_{topic}_help --nonsense; print rc=$?")
    assert "I do not know the option" in r
    assert f"get_{topic}_help --help" in r
    assert "rc=2" in r


# --- a topic that has no detail must not pretend it does --------------------


@pytest.mark.parametrize("topic", DETAIL_TOPICS)
def test_a_topic_with_detail_advertises_it(run, topic):
    assert "--detailed for the rest" in run(f"get_{topic}_help")


@pytest.mark.parametrize("topic", FLAT_TOPICS)
def test_a_topic_without_detail_does_not_advertise_detail(run, topic):
    """Offering --detailed on a topic that has none is a promise the tool
    cannot keep, and the reader has no way to tell which topics are which."""
    r = run(f"get_{topic}_help")
    assert "--detailed for the rest" not in r
    assert run(f"get_{topic}_help --detailed").stdout == r.stdout


def test_th_detail_prints_everything_outside_a_topic(run):
    """Someone calling the body directly — or an extension function reused
    elsewhere — should get all of it. Defaulting the other way would silently
    truncate output nobody asked to truncate."""
    r = run("_th_help_git")
    assert "Worktrees" in r


# --- the pager --------------------------------------------------------------


def test_piped_output_is_never_paged(run):
    """`get_git_help | grep push` must not hang, and `> notes.txt` must be
    plain text. TH_PAGER is set to something that would be unmistakable in the
    output if it ran."""
    r = run("get_git_help --detailed", env={"TH_PAGER": "sed s/^/PAGED:/"})
    assert "PAGED:" not in r
    assert "\x1b[" not in r.stdout


def test_a_long_view_is_paged_on_a_terminal(run_tty):
    r = run_tty("get_git_help --detailed", env={"TH_PAGER": "sed s/^/PAGED:/"})
    assert "PAGED:" in r


def test_a_short_view_is_not_paged_on_a_terminal(run_tty):
    """Paging something that already fits is how a tool earns a permanent
    TH_NO_PAGER=1 in everybody's rc file."""
    r = run_tty("get_mac_help", env={"TH_PAGER": "sed s/^/PAGED:/"})
    assert "PAGED:" not in r
    assert "Stop .DS_Store" in r


def test_th_no_pager_turns_it_off(run_tty):
    r = run_tty(
        "get_git_help --detailed",
        env={"TH_PAGER": "sed s/^/PAGED:/", "TH_NO_PAGER": "1"},
    )
    assert "PAGED:" not in r
    assert "Worktrees" in r


def test_colour_survives_the_pager(run_tty):
    """Measuring the output means capturing it, and capturing makes stdout a
    pipe — so th_use_color goes false and every escape silently vanishes. The
    result looks like a working monochrome theme, which is why this is asserted
    rather than eyeballed."""
    r = run_tty(
        "get_git_help --detailed",
        env={"TH_PAGER": "cat", "TH_NO_COLOR": ""},
    )
    assert "\x1b[" in r.stdout


def test_rows_falls_back_when_lines_is_zero(run):
    """LINES is 0 off a tty, not empty — the same trap COLUMNS had, where
    ${LINES:-24} never fires precisely where it is needed."""
    r = run("unset LINES; th_rows")
    assert r.stdout.strip() == "24"
