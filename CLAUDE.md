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
bash scripts/check-syntax.sh                        # 24 files, zsh + bash parsers
bash scripts/test-user-file-loads.sh                # 33 assertions in a throwaway HOME
bash scripts/test-user-file-loads.sh --self-check   # must FAIL — proves the above can
bash scripts/test-macos-bash.sh                     # 22 assertions, installer under real bash 3.2 (docker)
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

## Every command has an `_info` twin, and it is generated

`get_git_help` and `get_git_info` are one command. `th_info_twin` in
`lib/topics.zsh` makes the second name from the first, and it is called from
three places: the topic entry-point generator, the `TH_ALSO` loop, and
`homebrew.help.sh` for the hand-written `get_brew_help`. Never write an `_info`
function by hand — a twin that drifts from its `_help` is worse than no twin.

**A function, not an alias**, and that is not a style choice: an alias defined
and used in the same parse unit is not expanded, so it would not work from a
script or from inside another function, and `whence -w` — which
`get_help_topics` is built on — cannot see one.

**`th_info_twin` validates before it evals, and that validation is
load-bearing.** The name reaches it from a `TH_ALSO` comment in a file this
tool did not write, so without the check a header line is arbitrary code at
shell startup. There is an assertion for exactly that; removing the validation
makes a header run `touch`.

## `TH_ALSO` and `TH_RELATED` are not the same thing

`TH_ALSO` is a **sub-section of this topic**, defined in this file: it always
prints, because it is part of the topic. `TH_RELATED` names a **separate
topic** — its own file, its own `selected` entry, its own `th_topics enable` —
and is only NAMED by default, printed under `--all`.

Getting this backwards is what the mac topic did: `_th_help_mac` called
`get_homebrew_help` outright, so `get_mac_help` was 132 lines of which 69 were
Homebrew and 21 were macOS. **A topic body must never call another topic's
entry point** — declare `TH_RELATED` and let `th_show_related` decide.

Two consequences worth knowing before touching `th_show_topic`:

- **Every entry point forwards `"$@"`**, and so does `th_info_twin`. Drop the
  forwarding anywhere along that chain and `--all` works on one spelling of the
  command and not the other.
- **`th_show_related` skips a topic already on `_th_topic_stack`, silently.**
  Two topics naming each other is a reasonable thing to write, and the loud
  re-entrancy warning is for a hook re-entering its OWN topic — a mistake.
  Without the skip the cycle still terminates, so the assertion covering it
  asserts the SILENCE, not the termination. A warning that fires on correct
  usage is one people learn to scroll past.

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
