# terminal-help

A shell reference that loads with your shell: `terminal-help.zsh` + `lib/*.zsh`
for the machinery, `help/<category>/<topic>.help.sh` for the content. It runs in
**zsh only**. PowerShell is a help *topic* here (`help/powershell/`), not a
second runtime — there is no `.ps1` in this repository. Nothing host-specific
ships; see the README for the `~/.zshrc-user.sh` and `~/.zshrc-help.d/`
contract.

## The gate

CI (`.github/workflows/ci.yml`, one job named `gate`) runs four steps, and all
four run locally:

```sh
bash scripts/check-syntax.sh                        # 21 files, zsh + bash parsers
bash scripts/test-user-file-loads.sh                # 18 assertions in a throwaway HOME
bash scripts/test-user-file-loads.sh --self-check   # must FAIL — proves the above can
bash scripts/test-macos-bash.sh                     # 19 assertions, installer under real bash 3.2 (docker)
```

**A missing parser is a failure, not a skip.** No zsh on the box means the zsh
files were not checked, and a run that quietly halves its coverage while
printing OK is the failure this project keeps guarding against.

**What cannot be tested is the content**, because it prints a cheat-sheet into
an interactive terminal — so a help file earns its confidence from `zsh -n` and
from someone reading the rendered output, not from an assertion. That is why the
parse gate matters more than usual: `lib/*.zsh` is sourced from a real person's
`~/.zshrc`, so a syntax error breaks their shell, not a test run.

## Every PR bumps `VERSION`

One bump per merged PR, no exceptions. It rides in the one line terminal-help
prints on **every shell**, so it is what a person reads back when they say what
they are running — and a version covering three different states of the code
identifies none of them. This was got wrong on #22 and #23, and needed #24 to
repair it.

## Two shapes of user content, and what they cost

`~/.zshrc-help.d/` (reachable as `~/.terminal-help/help/user`, a symlink) holds
files the installer never touches:

- **A topic** — a `*.help.sh` with `TH_TOPIC`/`TH_EMOJI`/`TH_DESC`.
  `get_<topic>_help` is *generated* from that header; never write it by hand.
- **An extension** — no header, just `th_extend <topic> <fn>`. It appends to a
  packaged topic, so an upgrade cannot overwrite it and it cannot go stale
  against a package file someone copied.

**User topics are not in `selected` and never can be** — `th_available_topics`
skips `help/user` — so anything comparing loaded topics against the manifest
must filter them out first. Getting that wrong made `th_doctor` warn on every
shell for anyone who wrote a file of their own (#22).
