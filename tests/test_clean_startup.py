"""A new shell prints the banner and NOTHING ELSE.

This tier exists because of a defect that four green checks could not see
(NEH-1091). While fixing NEH-1060, an intermediate version declared
`local ae ad rest` bare; zsh's `local` PRINTS a parameter that already exists,
so from the second TH_ALSO line of any file onwards every new shell dumped

    ae=🌱
    ad='branch naming and commit messages'
    rest=' 🌱 | branch naming and commit messages'

into the terminal. It was caught by eye.

`test-user-file-loads.sh` gained a guard for it in #40 — but that guard greps
for `name=value`-shaped lines, which is the shape of that one defect. Measured
2026-08-22 on `main`: planting a stray `print -r -- "loading sub-section $fn"`
at load time — six junk lines in every shell — left **all four checks green**,
exit 0, 37 assertions and 165 tests passing. A guard that knows the shape of
the bug it already caught does not generalise to the next one.

So these tests do not look for noise. They assert the WHOLE of what a new shell
printed, against exactly what it is supposed to print. Anything unexpected fails
whatever shape it takes.

WHY EACH TEST FIRST PROVES THE TOOL LOADED
------------------------------------------
"Nothing unexpected was printed" is trivially true of a shell that printed
nothing at all — a source that aborts on a syntax error emits no noise and would
sail through a naive version of this file. That is this tier's own
green-over-an-empty-set trap, and it is not hypothetical: an aborted source is
exactly what a bad edit to lib/*.zsh produces.

Every test therefore runs a positive control in the same shell — the topics
really are registered and an entry point really is callable — before it is
allowed to conclude anything about cleanliness.
"""

from __future__ import annotations

from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
VERSION = (REPO / "VERSION").read_text().strip()

#: Printed only when TH_QUIET is empty. TH_NO_COLOR=1 is set by the harness, so
#: this is the literal text, not a pattern over escape codes.
BANNER = f"🧰 terminal-help v{VERSION} · get_help"

#: Separates what the SOURCE printed from what the probe printed. The harness
#: concatenates the two streams, so the load-time output is everything before it.
MARK = "---END-OF-LOAD---"

#: The probe: the tool is loaded if a generated entry point exists and the topic
#: table was populated. Both, because either alone can be true of a half-loaded
#: tree — the functions are generated from the same table the count reads.
PROBE = (
    f'print -r -- "{MARK}"\n'
    'th_defined get_mac_help && print -r -- "PROBE_ENTRYPOINT_OK"\n'
    'print -r -- "PROBE_TOPICS=${#TH_TOPIC_ORDER}"\n'
)


def startup(run, **kwargs):
    """Source terminal-help, then prove it loaded. Returns its load-time lines.

    Fails the test rather than returning if the positive control did not hold,
    so no caller can accidentally assert cleanliness over a shell that died.
    """
    result = run(PROBE, capture_load=True, **kwargs)
    assert MARK in result.stdout, (
        "the shell never reached the probe — terminal-help did not finish "
        f"sourcing, so this test can prove nothing. It printed:\n{result.stdout}"
    )
    loaded, probed = result.stdout.split(MARK, 1)

    assert "PROBE_ENTRYPOINT_OK" in probed, (
        "get_mac_help is not defined, so terminal-help did not really load and "
        "an absence of noise would mean nothing."
    )
    n_topics = int(probed.split("PROBE_TOPICS=")[1].split()[0])
    assert n_topics >= 5, f"only {n_topics} topic(s) registered — the tree did not load"

    return [line for line in loaded.splitlines() if line.strip()]


# ── the assertions ───────────────────────────────────────────────────────────


def test_a_quiet_shell_prints_absolutely_nothing(run) -> None:
    lines = startup(run)  # the harness sets TH_QUIET=1
    assert lines == [], (
        f"a quiet startup printed {len(lines)} line(s) it should not have:\n"
        + "\n".join(f"    {line}" for line in lines)
    )


def test_a_normal_shell_prints_the_banner_and_only_the_banner(run) -> None:
    lines = startup(run, env={"TH_QUIET": ""})
    assert lines == [BANNER], (
        f"expected exactly the banner, got {len(lines)} line(s):\n"
        + "\n".join(f"    {line}" for line in lines)
    )


def test_two_well_formed_TH_ALSO_lines_add_nothing(run, tmp_path: Path) -> None:
    """The exact shape that broke: `local` re-declared on the second iteration.

    One TH_ALSO line cannot catch it — the parameters do not exist yet on the
    first pass — so the file deliberately carries two.
    """
    d = tmp_path / "help.d"
    d.mkdir()
    (d / "twoalso.help.sh").write_text(
        "# TH_TOPIC: twoalso\n"
        "# TH_EMOJI: 🧪\n"
        "# TH_DESC:  a topic with two well-formed TH_ALSO lines\n"
        "# TH_ALSO:  get_twoalso_a_help | 🅰 | the first sub-section\n"
        "# TH_ALSO:  get_twoalso_b_help | 🅱 | the second sub-section\n"
        "_th_help_twoalso() { th_row 'X:' 'BODY' }\n"
    )
    lines = startup(run, user_help_dir=d)
    assert lines == [], (
        f"loading a user file printed {len(lines)} line(s) it should not have:\n"
        + "\n".join(f"    {line}" for line in lines)
    )


def test_a_malformed_file_warns_and_prints_nothing_beyond_the_warning(
    run, tmp_path: Path
) -> None:
    """A warning here is CORRECT output, so it is allowed for by name.

    Listing the permitted lines rather than loosening the matcher is the whole
    point: `assert "no |" in output` would pass with fifty other lines beside
    it, which is the failure this tier was written to end.
    """
    d = tmp_path / "help.d"
    d.mkdir()
    (d / "nopipe.help.sh").write_text(
        "# TH_TOPIC: nopipe\n"
        "# TH_EMOJI: 🧪\n"
        "# TH_DESC:  a topic whose TH_ALSO line forgot its pipes\n"
        "# TH_ALSO:  get_nopipe_sub_help\n"
        "_th_help_nopipe() { th_row 'X:' 'BODY' }\n"
    )
    # COLUMNS is pinned wide on purpose. The note wraps at 80, and a wrapped
    # continuation line carries neither the file name nor the function name —
    # so a matcher loose enough to accept it would be loose enough to accept
    # anything, which is the failure this file exists to end. Pin the width and
    # the expected output is two exact lines; the wrapping itself is already
    # covered by the width tests below.
    lines = startup(run, user_help_dir=d, columns=200)

    assert len(lines) == 2, (
        f"expected exactly the two-line TH_ALSO warning, got {len(lines)} line(s):\n"
        + "\n".join(f"    {line}" for line in lines)
    )
    assert "nopipe.help.sh" in lines[0] and "get_nopipe_sub_help" in lines[0], (
        f"the warning does not name the file and the function: {lines[0]!r}"
    )
    assert "the format is" in lines[1], (
        f"the second line is not the format hint: {lines[1]!r}"
    )


@pytest.mark.parametrize("columns", [40, 80, 200])
def test_the_banner_is_one_line_at_every_width(run, columns: int) -> None:
    """A banner that wraps is still noise, just noise that looks intentional."""
    lines = startup(run, env={"TH_QUIET": ""}, columns=columns)
    assert lines == [BANNER], (
        f"at COLUMNS={columns} the banner was {len(lines)} line(s):\n"
        + "\n".join(f"    {line}" for line in lines)
    )
