"""The harness: start a real zsh, source the repo, run a command, read what it printed.

Nothing here tests Python. Every assertion in this tier is about the bytes a
real zsh emitted, because that is the only thing a person ever sees.

Two rules this file exists to enforce, both learned the expensive way elsewhere
in this repo:

**A missing tool is a failure, not a skip.** No zsh means the tier tested
nothing, and a suite that reports success over an empty set is worse than no
suite. `pytest_configure` raises rather than deselecting, so the run stops instead of
reporting green over nothing.

**The developer's own environment must not leak in.** terminal-help EXPORTS
TH_HOME, TH_VERSION and TH_USER_FILE, so every shell on a machine where it is
installed hands them to its children — including the zsh started here. That
already produced a red suite on a healthy tree once (16/1 locally, 17/0 in CI,
identical code). `run` scrubs them and points TH_USER_HELP_DIR at a directory
that does not exist, so a file of the developer's own cannot join the output.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent

# Inherited TH_* would change what the shell under test loads and where it
# loads it from. Every one of these is exported by terminal-help itself.
_SCRUB = (
    "TH_HOME",
    "TH_VERSION",
    "TH_USER_FILE",
    "TH_SELECTED",
    "TH_USER_HELP_DIR",
    "TH_QUIET",
    "TH_NO_COLOR",
    "TH_NO_RELAUNCH",
    "TH_PAGER",
    "TH_NO_PAGER",
    "TH_WIDTH",
    "TH_LABEL_WIDTH",
)


@dataclass(frozen=True)
class Result:
    """What the shell printed, and how it exited."""

    stdout: str
    rc: int

    @property
    def lines(self) -> list[str]:
        return self.stdout.splitlines()

    @property
    def n_lines(self) -> int:
        return len(self.lines)

    def __contains__(self, needle: str) -> bool:
        return needle in self.stdout


def pytest_configure(config: pytest.Config) -> None:
    """Refuse to run at all rather than quietly testing nothing."""
    if shutil.which("zsh") is None:
        raise pytest.UsageError(
            "zsh is not installed, so this tier can test NOTHING. "
            "Install it (apt-get install zsh / brew install zsh). "
            "A skipped check is not a passed check."
        )


def _run(
    script: str,
    *,
    columns: int = 80,
    lines: int = 40,
    env: dict[str, str] | None = None,
    user_help_dir: str | Path | None = None,
    capture_load: bool = False,
    timeout: float = 30.0,
) -> Result:
    """Source terminal-help in a clean zsh at a fixed size, then run `script`.

    `zsh -f` skips every startup file, so the developer's ~/.zshrc cannot
    contribute. COLUMNS and LINES are set explicitly because zsh reports them as
    0 off a tty, and layout depends on both.

    `capture_load=True` keeps whatever the SOURCE itself printed. It is off by
    default because load-time noise would land in every assertion about a
    command's output — but some warnings are emitted at load time and nowhere
    else (th_extend refusing a bad hook, th_info_twin refusing a bad name), and
    with the default those are invisible to the test rather than absent from
    the tool. That distinction is worth a parameter: the first version of this
    harness swallowed them and the failure read as a missing feature.
    """
    environ = {k: v for k, v in os.environ.items() if k not in _SCRUB}
    environ.update(
        {
            "COLUMNS": str(columns),
            "LINES": str(lines),
            "TH_QUIET": "1",  # no banner: it is noise in every assertion
            "TH_NO_COLOR": "1",  # assert on text, not on escape codes
            "TH_USER_HELP_DIR": str(user_help_dir or "/nonexistent-th-user-dir"),
        }
    )
    if env:
        environ.update(env)

    # COLUMNS/LINES are re-set after the source, because sourcing runs code that
    # can read them and zsh will happily reset them for a shell it thinks owns a
    # terminal.
    redirect = "" if capture_load else " > /dev/null 2>&1"
    body = (
        f"source {REPO}/terminal-help.zsh{redirect}\n"
        f"COLUMNS={columns}; LINES={lines}\n"
        f"{script}\n"
    )
    proc = subprocess.run(
        ["zsh", "-f"],
        input=body,
        env=environ,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=REPO,
    )
    return Result(stdout=proc.stdout + proc.stderr, rc=proc.returncode)


@pytest.fixture
def run():
    """Run a command in a freshly sourced terminal-help and return a Result."""
    return _run


def _discover_topics() -> list[str]:
    """Every packaged topic, read from the headers the tool itself reads.

    Discovered rather than listed by hand: a hardcoded list silently stops
    covering the topic somebody adds next, and the count is what makes that
    visible.
    """
    topics = []
    for path in sorted(REPO.glob("help/*/*.help.sh")):
        for line in path.read_text().splitlines()[:20]:
            if line.startswith("# TH_TOPIC:"):
                topics.append(line.split(":", 1)[1].strip())
                break
    return topics


TOPICS = _discover_topics()


def pytest_report_header(config: pytest.Config) -> list[str]:
    """Say what is about to be examined. `0 failed over 0 topics` and
    `0 failed over 12` print the same verdict and are different facts."""
    return [f"terminal-help: {len(TOPICS)} packaged topic(s) discovered: {', '.join(TOPICS)}"]
