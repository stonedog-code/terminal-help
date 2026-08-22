# terminal-help

A shell reference that loads with your shell: `terminal-help.zsh` + `lib/*.zsh`
for the machinery, `help/<category>/<topic>.help.sh` for the content. It runs in
**zsh only**. PowerShell is a help *topic* here (`help/powershell/`), not a
second runtime — there is no `.ps1` in this repository. Nothing host-specific
ships; see the README for the `~/.zshrc-user.sh` and `~/.zshrc-help.d/`
contract.

## The gate

CI (`.github/workflows/ci.yml`, one job named `gate`) runs six steps, and all
six run locally:

```sh
bash scripts/check-syntax.sh                        # 27 files, zsh + bash parsers
bash scripts/test-user-file-loads.sh                # 34 assertions in a throwaway HOME
bash scripts/test-user-file-loads.sh --self-check   # must FAIL — proves the above can
bash scripts/test-macos-bash.sh                     # 24 assertions, installer under real bash 3.2 (docker)
bash scripts/test-behaviour.sh                      # 165 pytest assertions driving a real zsh
bash scripts/test-behaviour.sh --self-check         # must FAIL — proves the above can
```

**The two suites answer different questions, which is why both exist.**
`test-user-file-loads.sh` asks whether a real `~/.zshrc` loads a real
`~/.zshrc-user.sh` — installation and startup, in a throwaway `$HOME`.
`test-behaviour.sh` asks what a command PRINTS, across a matrix of topics and
flags. Written as linear bash the second one is a thousand lines nobody reads;
`pytest` parametrises it. **Nothing in `tests/` tests Python** — every
assertion is about the output of a real zsh, and pytest is only the harness.

**A missing tool is a failure, not a skip** — `zsh`, `uv` and `docker` alike. No zsh on the box means the zsh
files were not checked, and a run that quietly halves its coverage while
printing OK is the failure this project keeps guarding against.

**What cannot be tested is the content**, because it prints a cheat-sheet into
an interactive terminal — so a help file earns its confidence from `zsh -n` and
from someone reading the rendered output, not from an assertion. That is why the
parse gate matters more than usual: `lib/*.zsh` is sourced from a real person's
`~/.zshrc`, so a syntax error breaks their shell, not a test run.

## The pytest tier: what to know before adding to it

- **`tests/conftest.py` scrubs every `TH_*` variable.** terminal-help *exports*
  `TH_HOME`, `TH_VERSION` and `TH_USER_FILE`, so on a machine where it is
  installed every child shell inherits them — including the one under test.
  That already produced a red suite on a healthy tree (16/1 locally, 17/0 in
  CI, identical code).
- **`capture_load=True` is needed for anything warned at LOAD time.** Sourcing
  is redirected to `/dev/null` by default so startup noise stays out of every
  assertion — but `th_extend` and `th_info_twin` refuse bad input while the
  file is being sourced, and with the default those warnings are invisible to
  the test rather than absent from the tool. The first version of the harness
  swallowed them and the failure read as a missing feature.
- **Topics are DISCOVERED from the headers**, not listed. `test_topics_were_discovered`
  guards the parametrised tests: an empty list would turn every one of them
  into a green test over nothing.
- **`.venv` is gitignored per platform** (`scripts/uv-env.sh` gives macOS
  `.venv-macos`), because this repo is reachable over SMB from two machines at
  once. `uv.lock` IS committed.

## Every PR bumps `VERSION`

One bump per merged PR, no exceptions. It rides in the one line terminal-help
prints on **every shell**, so it is what a person reads back when they say what
they are running — and a version covering three different states of the code
identifies none of them. This was got wrong on #22 and #23, and needed #24 to
repair it.

**Bump with the script, not by hand:**

```sh
bash scripts/set-version.sh 0.42.0
```

`VERSION` is not the only place the version appears — the README quotes the
banner that `VERSION` feeds, and editing one without the other is the DEFAULT
outcome rather than a slip. Measured over this repo's history: 32 commits
touched `VERSION` and only 22 touched `README.md`. The drift that produced was
21 versions wide (README said v0.14.0 against a `VERSION` of 0.35.0) and every
tier stayed green throughout, because nothing compared a document to the code.

`scripts/check-docs-version.sh` is now that comparison and gates the merge, so
a hand-edit that misses the README fails CI. It checks the **banner form
only** — prose naming an old version on purpose (*"the v0.12.0 regression"*,
*"as of v0.32.0"*) is history and is deliberately left alone.

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

## Four views, one body, and where the cut goes

A topic prints a **summary** by default and its full content under
`--detailed`. Two independent switches, not one enum: `--detailed` is how much
of *this* topic, `--related` is how much of its neighbours, and `--all` is
both. That is why `--all` must stay byte-identical to `--detailed --related` —
the moment it becomes its own branch the three views start to drift, and there
is an equality assertion holding it.

**The split is a guard, not a second function.** A help file writes
`th_detail || return` at the point where the summary ends. Two bodies would
mean the content exists twice and the summary stops matching the detail the
first time somebody edits one; one body with a cut makes the summary a prefix
of the detail **by construction**.

**The guard goes in `_th_help_<topic>`, never at the top of a `TH_ALSO`
sub-function.** Both placements look right and hide the same text from the
summary — but the wrong one truncates that one sub-section rather than the
topic, so a second sub-function below it still prints and the prefix property
breaks. Two of the first nine landed there. `test_the_cut_is_inside_the_topic_body`
asserts the cause, because the symptom (`test_detailed_is_strictly_more_than_summary`
going red on `powershell`) is three steps away from it.

**A topic that fits one page gets no guard and is offered no `--detailed`.**
`_th_has_detail_<topic>` is defined by grepping the file for the guard, so the
hint cannot promise a view that does not exist. Do not add a header field for
this — a second declaration is a second thing that can disagree with the code.

**`th_detail` returns TRUE when `_th_view` is unset**, so calling
`_th_help_git` directly prints everything. Defaulting the other way would
silently truncate output nobody asked to truncate.

**Summary output is capped at 40 lines at 80 columns, per topic, by a test.**
When it fails, move the guard earlier — the assertion says so by name.

## Paging: `th_page` wraps every entry point

- It pages only when stdout is a **terminal** and the output is taller than it.
  `get_git_help | grep push` must not hang and `> notes.txt` must be plain
  text, which is why the `[[ -t 1 ]]` test is load-bearing rather than
  cosmetic.
- **Measuring means capturing, and capturing makes stdout a pipe** — so
  `th_use_color` would strip every escape from output that IS going to a
  terminal. `TH_FORCE_COLOR` exists for exactly that one call and nothing else.
- `th_rows` has the same shape as `th_cols` for the same reason: `LINES` is `0`
  off a tty, not empty, so `${LINES:-24}` never fires where it is needed.
- The pager tests allocate a **real pty**. A subprocess with a pipe on stdout
  can only ever prove the negative.

## `TH_ALSO` and `TH_RELATED` are not the same thing

`TH_ALSO` is a **sub-section of this topic**, defined in this file: it belongs
to the topic and is governed by the topic's own cut — above `th_detail` it is
in the summary, below it is in the detailed view. `TH_RELATED` names a
**separate topic** — its own file, its own `selected` entry, its own
`th_topics enable` — and is only NAMED by default, summarised under `--related`
and `--all`, and never shown in full from somewhere else.

Getting this backwards is what the mac topic did: `_th_help_mac` called
`get_homebrew_help` outright, so `get_mac_help` was 132 lines of which 69 were
Homebrew and 21 were macOS. **A topic body must never call another topic's
entry point** — declare `TH_RELATED` and let `th_show_related` decide.

Two consequences worth knowing before touching `th_show_topic`:

- **Every entry point forwards `"$@"`**, and so does `th_info_twin`. Drop the
  forwarding anywhere along that chain and `--all` works on one spelling of the
  command and not the other.
- **A related topic is shown at SUMMARY depth and expansion stops after one
  level.** Neither is incidental: showing a neighbour in full is the original
  complaint, and walking the graph turns one question into the whole manual.
- **`th_show_related` skips a topic already on `_th_topic_stack`, silently —
  and what that catches is a topic listing ITSELF in `TH_RELATED`.** It is not
  what keeps a mutual pair quiet: expansion is one level, so `python` and
  `pytest` never re-enter each other at all. This entry claimed otherwise for a
  release, and the correction came from a plant — removing the skip left every
  test passing, which meant the line was covered by nothing. The reachable case
  now has its own assertion. A warning that fires on correct usage is one
  people learn to scroll past, so the skip stays.

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
