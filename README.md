# 🧰 terminal-help

A reference that lives in your shell. `get_help` prints the index; every
section is a command away — git worktrees, the `gh` pull-request loop, `uv`,
whatever you add yourself.

It runs in **zsh** — macOS, Linux, WSL — and prints exactly one line when a
shell starts:

```
🧰 terminal-help v0.13.0 · get_help
```

Everything host-specific — your servers, your shares, your aliases — lives in
`~/.zshrc-user.sh`, a file this project **creates once and then never opens
again**, plus `~/.zshrc-help.d/` for help you write yourself. Nothing personal is in the
repository, which is what makes it publishable.

```
  🌳 Worktrees — one feature, one branch, one worktree, one PR
  Create:                  git worktree add ../{repo}-{slug} -b feat/{slug}
                           ↳ new directory, new branch, checked out and ready
  Remove when merged:      git worktree remove ../{repo}-{slug}
```

---

## Quick start — the installer asks which platforms

```sh
git clone git@github.com:nehsa-net/terminal-help.git ~/src/terminal-help
cd ~/src/terminal-help
./install.sh
```

```
🧰 terminal-help v0.13.0
  Which shells should it be installed for? Pick as many as apply.

    1  🍎  macOS       — adds a source line to ~/.zshrc
    2  🐧  Linux       — adds a source line to ~/.zshrc
    3  🪟  Windows     — adds a line to your PowerShell $PROFILE
    4  🌍  All three

  ↳  detected: linux
  Numbers, comma or space separated [2]:
```

Pick `1`, `2`, `3`, any combination (`1,3`), or `4` for all three. The
installer:

- **copies the runtime into `~/.terminal-help`** and points `~/.zshrc` at
  `$HOME`, never at the clone — see below;
- **asks before touching your `~/.zshrc`.** Decline and nothing is written —
  it prints the block for you to paste and stops;
- adds **one marked block** to the `~/.zshrc` or `$PROFILE` you already have —
  it never overwrites your config, and re-running replaces its own block
  instead of appending a second one;
- backs the file up first (`.terminal-help.bak`);
- tells you if zsh is missing, or is installed but is not your login shell;
- **creates `~/.zshrc-user.sh` if it does not exist**, and ignores it entirely
  if it does. See below — that file is yours.

Non-interactive, for a setup script:

```sh
./install.sh --targets mac,linux,windows --yes
./install.sh --uninstall              # removes the block and ~/.terminal-help
```

Then open a new terminal and type `get_help`.

### Where things end up

| Path | What it is | Touched by an upgrade? |
|---|---|---|
| `~/.zshrc` | the marked block, ~10 lines | rewritten, nothing else |
| `~/.zshrc-user.sh` | **yours** — aliases, exports, hooks | **never** |
| `~/.zshrc-help.d/` | **yours** — topics and extensions, any depth | **never** |
| `~/.terminal-help/` | the runtime: `lib/`, `help/`, `selected`, `VERSION` | replaced |
| the clone | source. Needed to install and to upgrade, and at no other time | — |

**The installer copies; it does not point at the clone.** That matters more than
it sounds: a clone lives in `~/src`, or on a network share, or in `/tmp`, and
none of those paths exist on the next machine. A `~/.zshrc` naming one is a
`~/.zshrc` that fails on every other machine — and it fails *badly*, because
when the `source` line dies, `th_source_user` is never defined and **your own
settings file silently never loads either**. Referencing `$HOME` cannot go wrong
that way. You can delete the clone after installing and everything keeps
working.

Even so, the block is written to survive a missing runtime: if
`~/.terminal-help` is gone, it loads `~/.zshrc-user.sh` directly, so your
aliases outlive the help.

And the reverse: **the runtime loads your settings file itself if nothing else
has.** The block calls `th_source_user` by name, because where your settings
come from should be visible in the file you actually open — but that line is
not something the tool depends on. A block written by an older installer, or
edited by hand, would otherwise leave your file unloaded, and the symptom is
silent and baffling: the version line still prints while nothing of yours does.
`th_source_user` is idempotent, so the explicit call costs nothing.

**Working on terminal-help itself?** `./install.sh --link` symlinks the clone
instead of copying it, so edits are live. Only do that on a machine where the
clone is permanent.

### Upgrading

```sh
cd ~/src/terminal-help && git pull && ./install.sh --yes
```

Re-running the installer is how you pick up a new version: it re-copies the
runtime into `~/.terminal-help`, refreshes its own block in your rc file, and
leaves everything else alone. `lib/` is replaced wholesale, so a section deleted
upstream does not linger. **`~/.zshrc-user.sh` is
never touched by an upgrade** — not read, not parsed, not merged, not backed
up, not even opened. The installer creates it once, if it is missing, and after
that has no business with it.

**On Windows, install inside WSL.** terminal-help is a zsh tool; there is no
PowerShell edition to install. `get_powershell_help` gives you the PowerShell
reference from the zsh side.

---

## Setting it up by hand

<details>
<summary>🍎 <b>macOS</b></summary>

macOS has shipped zsh as the default login shell since Catalina, so there is
nothing to install. Confirm, then add one line:

```sh
echo $SHELL                       # expect /bin/zsh
chsh -s /bin/zsh                  # only if it is not
echo 'source ~/src/terminal-help/terminal-help.zsh' >> ~/.zshrc
```

If your Mac is on bash (an old account, or a machine upgraded from Mojave),
`chsh -s /bin/zsh` and open a new terminal — the change applies at next login,
not to the shell you typed it in.
</details>

<details>
<summary>🐧 <b>Linux</b> — including how to install zsh</summary>

Most distributions do not ship zsh. Install it, make it your login shell, then
add the source line:

| Distribution | Command |
|---|---|
| Debian / Ubuntu | `sudo apt update && sudo apt install -y zsh` |
| Fedora / RHEL | `sudo dnf install -y zsh` |
| Arch | `sudo pacman -S zsh` |
| Alpine | `sudo apk add zsh` |
| openSUSE | `sudo zypper install zsh` |

```sh
chsh -s $(which zsh)              # applies at your NEXT login
exec zsh                          # try it right now, in this terminal
echo 'source ~/src/terminal-help/terminal-help.zsh' >> ~/.zshrc
```

`chsh` needs your password and edits `/etc/passwd`; it does **not** change the
shell you are standing in. `echo $0` tells you the running shell, `echo $SHELL`
only the configured login default — they disagree until you log out and in.

No root on the box? You can still run zsh from your home directory:

```sh
apt-get download zsh zsh-common
dpkg -x zsh_*.deb ~/local && dpkg -x zsh-common_*.deb ~/local
~/local/usr/bin/zsh
```
</details>

<details>
<summary>🪟 <b>Windows</b> — PowerShell, and how to get zsh</summary>

terminal-help runs in zsh, so on Windows it lives in WSL. PowerShell is
covered as a *topic* (`get_powershell_help`), not as a second implementation.

**zsh on Windows** has two honest answers, and a native Windows zsh is not one
of them:

1. **WSL — recommended.** A real Linux, so the zsh edition runs unchanged.

   ```powershell
   wsl --install -d Ubuntu
   ```

   then, inside WSL, follow the 🐧 Linux instructions above:

   ```sh
   sudo apt update && sudo apt install -y zsh
   chsh -s $(which zsh)
   ```

   Keep the clone on the WSL side (`~/src/terminal-help`, not `/mnt/c/...`) —
   I/O across the `/mnt/c` boundary is far slower.

2. **MSYS2.** `pacman -S zsh` gives you zsh, but with a hybrid PATH where
   Windows tools and MSYS tools disagree about what a path is. Git for Windows
   ships **bash**, not zsh, so Git Bash alone will not do.

Running both WSL and PowerShell? terminal-help installs in WSL only — it is a
zsh tool. What it gives you on the PowerShell side is `get_powershell_help`:
the profile, the execution policy, and the cmdlets worth knowing, read from
your zsh prompt while you write PowerShell in the other window.
</details>

---

## 🔒 Your half: `~/.zshrc-user.sh`

The repository contains no hostnames, no usernames and no personal aliases —
and neither does the block the installer puts in your `~/.zshrc`. Everything
that is yours goes in one file beside it:

```
~/.zshrc          the terminal-help block — rewritten by the installer
~/.zshrc-user.sh  YOURS — aliases, exports, PATH, hooks. Nothing writes here.
```

`~/.zshrc` sources it on every shell, by name, on its own line, so what loads
and in what order is visible in the file people actually open:

```zsh
# >>> terminal-help >>>
# Put YOUR shell settings in ~/.zshrc-user.sh — aliases, exports, PATH, and
# the get_user_info / user_on_load hooks. NOT in this file: everything between
# these two markers is rewritten by terminal-help's installer.
export TH_HOME="/home/you/src/terminal-help"
export TH_USER_FILE="${ZDOTDIR:-$HOME}/.zshrc-user.sh"
source "$TH_HOME/terminal-help.zsh"   # the reference help
th_source_user                        # your settings, from $TH_USER_FILE
# <<< terminal-help <<<
```

**The installer creates that file once and then leaves it alone forever.** It
is not read, not parsed, not copied, not backed up, not migrated — an upgrade
cannot lose or reformat something it never opens. It is created with a short
comment header explaining what it is for, so an otherwise empty file is not a
mystery; everything below that is yours to write.

Two function names are all terminal-help asks of it, and both are optional:

| Hook | Called when | Typical contents |
|---|---|---|
| `get_user_info` | you type it | your own reference sections — internal hosts, runbooks, the flag you always forget |
| `user_on_load` | **every new shell** | the only thing besides the version line that may print |

Define neither and the file is still doing its job — aliases, exports and
functions need no hooks, and `get_help` says so rather than calling the file
empty.

The file the installer creates carries its own instructions in comments — there is no separate example to copy from and get out of step with.

**No secrets in it.** It is private, not encrypted: it sits in your home
directory in plain text and every backup copies it. Passwords and tokens belong
in the login keychain, Credential Manager, or a password manager's CLI — read
them at the moment you need them rather than storing them in a file every shell
sources.

**Keeping it elsewhere:** export `TH_USER_FILE` (or `$env:TH_USER_FILE`) before
the source line and it is read from there instead.

## What prints, and when

| | |
|---|---|
| On every new shell | one line: `🧰 terminal-help v0.13.0 · get_help` |
| Plus | whatever *your* `user_on_load` chooses to print — nothing, by default |
| Everything else | only when you ask for it by name |

Silence even the version line with `TH_QUIET=1` (put it in `~/.zshenv`, or
`$env:TH_QUIET = 1` for PowerShell). Note that this also skips `user_on_load`.

---

## The topics

| Command | |
|---|---|
| `get_help` | ❓ the curated index (alias: `help_me`) |
| `get_help_topics` | 📋 every help command that exists, plus how to drive terminal-help |
| `get_versions` | 📋 OS, shell, python, uv, git, gh, node, brew |
| `th_topics` | 🗂 what is selected, and turn topics on or off |
| `th_doctor` | 🩺 why isn't my help — or my settings file — loading? |
| `get_git_help` | 🌿 git — with the three below |
| `get_git_branch_help` | 🌱 branch naming, Conventional Commits |
| `get_git_worktree_help` | 🌳 worktrees, and the six rules that make them work |
| `get_git_pr_help` | 🔀 the `gh` pull-request loop, reviewing, red checks |
| `get_python_help` | 🐍 Python — with the two below |
| `get_uv_help` | 📦 `uv`: projects, dependencies, venvs |
| `get_uvicorn_help` | ⚡ uvicorn and FastAPI launch lines |
| `get_mac_help` | 🍎 keys, the default shell, Finder — then Homebrew |
| `get_mac_keys_help` | ⌨️ moving the cursor: why Home is not Home on a Mac |
| `get_homebrew_help` | 🍺 brew — upgrading, Brewfiles, services, what bites (`get_brew_help`) |
| `get_claude_help` | 🤖 Claude Code — CLAUDE.md, settings.json, the CLI |
| `get_copilot_help` | 🧑‍✈️ GitHub Copilot — instructions files, chat, `gh copilot` |
| `get_linux_help` | 🐧 installing zsh, packages, services, ports |
| `get_windows_help` | 🪟 winget, WSL, zsh on Windows |
| `get_powershell_help` | 🔷 profile, execution policy, cmdlets from a Unix shell |
| `get_user_info` | 🔒 yours, from `~/.zshrc-user.sh` |

Only selected topics are defined; `th_topics` shows the rest.

## 🗂 The catalogue: one folder, one format

All help lives under `help/`, one file per topic, every file the same shape
whatever it is about:

```
help/
├── mac/mac.help.sh                🍎  platforms
├── linux/linux.help.sh            🐧
├── windows/windows.help.sh        🪟
├── powershell/powershell.help.sh  🔷  a shell you may not be running
├── technologies/git.help.sh       🌿  tools, one file each
├── technologies/python.help.sh    🐍
└── user/                          🧩  YOURS — a symlink to ~/.zshrc-help.d
```

A file declares itself in a header comment, and that header is the only
metadata anywhere — the installer (bash) and the loader (zsh) read the same
three lines:

```zsh
# TH_TOPIC: git
# TH_EMOJI: 🌿
# TH_DESC:  git — everyday commands, branches, worktrees, pull requests
# TH_ALSO:  get_git_worktree_help | 🌳 | worktrees, and the rules

_th_help_git() {
    th_head "🌿" "Git"
    th_row  "Where am I:" "git status -sb"
}
```

`get_git_help` is **generated** from that header. You never write it, which is
what lets someone else extend your topic without editing your file.

**PowerShell is content, not a runtime.** terminal-help does not run in
PowerShell; `get_powershell_help` is a reference — the profile, execution
policy, the cmdlets worth knowing from a Unix shell — that you read from zsh.

## ✅ Choosing your topics

`./install.sh` asks which ones you want:

```
     1  🐧  linux        Linux — installing zsh, packages, services, ports
     2  🍎  mac          macOS — Homebrew, the default shell, Finder
     3  🔷  powershell   PowerShell — profile, execution policy, cmdlets
     4  🌿  git          git — everyday commands, branches, worktrees, PRs
     5  🐍  python       Python — uv, virtualenvs, uvicorn
     6  🪟  windows      Windows — winget, WSL, and getting zsh onto the machine

  Numbers (comma or space separated), "a" for all [linux git python]:
```

Pick `4` and `get_git_help` works. The default is your platform plus the
common technologies.

**Everything is installed either way; the selection decides what loads.** That
matters six months later: `th_topics enable mac` turns one on in a second, with
no clone, no network, and no reinstall — the usual way that goes wrong is a tool
that only copied what you asked for and then needs the original download back.

```
th_topics                    # what exists, ✅ selected, ⬜ idle
th_topics enable powershell
th_topics disable windows
th_topics all
```

`get_help` lists what is idle rather than pretending it does not exist.

## 🧩 Your own help, and extending the built-ins

Everything of yours lives in `~/.zshrc-help.d/` — created once by the
installer, **never touched again**, and reachable from inside the tree as
`~/.terminal-help/help/user` (a symlink; see the note below).

**A topic of your own** — any `*.help.sh`, at any depth, so you can keep
folders:

```zsh
# ~/.zshrc-help.d/work/deploy.help.sh
# TH_TOPIC: deploy
# TH_EMOJI: 🚀
# TH_DESC:  our deploy runbook

_th_help_deploy() {
    th_head "🚀" "Deploy"
    th_row  "Staging:" "./deploy.sh staging"
    th_note "the flag you always forget goes here, where it is private"
}
```

`get_deploy_help` prints it; `get_help` lists it under 🧩 Yours.

**An extension** — add to a topic that ships with terminal-help, without
touching the package file:

```zsh
# ~/.zshrc-help.d/extensions/git.help.sh
_th_ext_git_mine() {
    th_sub "🔧" "My git shortcuts"
    th_row "Fixup:" "git commit --fixup HEAD && git rebase -i --autosquash"
}
th_extend git _th_ext_git_mine
```

`get_git_help` now prints the built-in content **and then yours**. This is the
whole point of generating the entry point: your rows are appended to a hook
list, so upgrading the package cannot overwrite your additions, and your
additions cannot go stale against a package file you copied and edited.
`get_help` marks the topic *"extended by one of your own files"*.

### Why `help/user` is a symlink

You asked for your files to sit under `help/user/`, and they do. But the
installer replaces the shipped categories wholesale on every upgrade, and user
data inside a directory something `rm -rf`s is one wrong glob away from being
deleted. So the path is real and the bytes are not in it: `help/user` points at
`~/.zshrc-help.d`, and `rm -rf` deletes a symlink rather than following it.
Both paths work; only one of them can ever be in the blast radius.

## 📋 `get_help_topics` — the complete list

`get_help` is the curated index: topics in a deliberate order, with their
sub-sections. `get_help_topics` is the flat one, **discovered at runtime** —
every `get_*_help` function actually defined in this shell, wherever it came
from:

```
  📦 From terminal-help (8)
  get_git_help             🌿 git — everyday commands, branches, worktrees, PRs
                           ↳ extended by one of your own files
  ...
  🧩 Yours (1)
  get_deploy_help          🚀 our deploy runbook

  ⬜ Installed but switched off (6)
  get_mac_help             th_topics enable mac
```

Discovered rather than listed, because a hardcoded list is wrong the moment
somebody drops a file into `~/.zshrc-help.d` — which is the entire point of
that directory. It also names the commands you *cannot* call yet, rather than
leaving them out of a list that claims to be complete.

It ends with **how to drive terminal-help itself**: the five commands, where
every file lives and who owns it, the three-line header that makes a topic of
your own, the `th_extend` shape for extending a built-in, the helper functions
you can call, and how to upgrade, re-select topics, contribute back and remove
it.

## 🩺 When something of yours does not run

```
th_doctor
```

It checks the install, the block in `~/.zshrc`, your settings file and your help
files, and prints **what it examined** rather than a verdict.

The failure it exists for is worth knowing about, because it is silent and it
has bitten:

> A settings file was copied out of the example, and the `#` markers on the
> commentary were lost along the way — leaving prose at the start of a line.
> One of those lines began with the word **`private`**, which zsh has as a
> builtin. A builtin misused at file scope does not merely print an error: it
> **aborts the rest of the file**. Every function below it — and the calls that
> were supposed to print at startup — silently never existed. The one error
> line had scrolled away hours earlier.

So `th_source_user` now checks what `source` returned and says
*"stopped early — everything below the failing line was not loaded"*, and
`th_doctor` finds the line, `zsh -n`s every file you own, and flags any line
that looks like prose without a `#`.

To see the first error yourself, in isolation:

```sh
zsh -f -c 'source ~/.zshrc-user.sh'
```

The first error is where it stopped.

## 📤 Contributing an extension back

Wrote something worth sharing? In the clone:

```sh
scripts/promote-extensions.sh          # writes PROMOTIONS.md
scripts/promote-extensions.sh --stdout
```

It collects every file in `~/.zshrc-help.d/extensions/`, works out which
packaged topic each one extends and which file that is, and writes a checklist
with the content ready to fold in.

**It edits no code, deliberately.** The obvious version of this script would
splice your function body into `_th_help_git`. Shell has no parser here, so
that means matching a closing brace with a regex — which breaks on a nested
function, a `case`, a brace inside a string, or `function f {`. A bad splice
corrupts the topic for everyone who installs next. A report a human folds in is
slower exactly once and never wrong.

## Layout

```
terminal-help/
├── terminal-help.zsh          the loader
├── lib/                       the machinery
│   ├── ui.zsh                 colour and layout helpers
│   ├── topics.zsh             the catalogue: headers, selection, extensions
│   ├── help.zsh               ❓ get_help
│   └── versions.zsh           📋 get_versions
├── help/                      the CONTENT — one file per topic
│   ├── mac/ linux/ windows/   platforms (mac also carries homebrew)
│   ├── powershell/            a shell you may not be running
│   ├── technologies/          git, python, claude, copilot
│   └── user/                  → symlink to ~/.zshrc-help.d (created at install)
├── scripts/
│   ├── check-syntax.sh        the gate
│   └── promote-extensions.sh  your extensions → a contribution checklist
├── install.sh                 topic selection, then install to ~/.terminal-help
├── VERSION
└── LICENSE
```

## Colour and emoji

256-colour ANSI, one palette in `lib/ui.zsh`. Colour is decided **per call**,
not once at load, so `get_git_help | less` and `get_git_help > notes.txt` come
out clean rather than full of escape codes.

- `NO_COLOR=1` or `TH_NO_COLOR=1` turns it off ([no-color.org](https://no-color.org)).
- Emoji need a font that has them. macOS Terminal, iTerm2, Windows Terminal and
  most Linux terminals are fine; the legacy Windows console host (`conhost`) is
  not — use Windows Terminal, or set `TH_NO_COLOR=1` and accept the tofu.

---

## Verified

Run against a real zsh 5.9, not eyeballed:

- **The catalogue** — every topic file parses and renders; `get_help` is built
  from the headers, and the index matches what is actually loaded.
- **Selection** — a manifest of three topics loads exactly those three, with the
  rest reported as idle. `th_topics enable powershell` turns one on **after the
  source clone was deleted**, which is the case that matters.
- **Extensions** — an `extensions/git.help.sh` appends to the built-in git
  topic; `get_git_help` prints the package content and then the user's; a
  re-install from a fresh package leaves the file's md5 unchanged and the
  extension still working.
- **A user topic of their own** — `~/.zshrc-help.d/work/deploy.help.sh` with a
  header becomes `get_deploy_help`, listed under 🧩 Yours.
- **Installed, then the clone deleted** — a real interactive zsh still prints
  the version line, loads `~/.zshrc-user.sh`, runs `user_on_load`, and renders
  every selected topic. Nothing outside `$HOME` is referenced at runtime.
- **The installer** — the topic menu on a pty (numbers, `a`, empty for the
  default), decline leaves `~/.zshrc` byte-identical, re-install leaves one
  block, uninstall removes the runtime and keeps both of your directories.
- **The gate** — `bash scripts/check-syntax.sh`: 15 files, exit 0, and proved
  non-vacuous by planting a syntax error in a help file and watching it fail.
- **Colour, in four directions** — present on a tty; absent when piped, under
  `NO_COLOR`, and under `TERM=dumb`.

**Not verified:** macOS itself — there is no Mac in the loop, so `brew`,
`defaults` and the mac topic's commands are unexercised as *commands* (the file
parses and renders); and the CI gate has still never executed on GitHub's
runners, because the org's Actions account is billing-locked.

## Design notes

**The `~/.zshrc-user.sh` split was reviewed by Gemini before it was built**
(`ask-gemini --review-plan`), and the review changed the design in five places:
the `source` line moved into `~/.zshrc` where it is visible rather than staying
hidden in the loader; the injected block uses `${ZDOTDIR:-$HOME}` instead of a
hardcoded `$HOME`; the prompt now comes *before* the old block is stripped, so
declining changes nothing; the PowerShell settings file is resolved from
`$PROFILE` rather than a hardcoded `Documents\PowerShell`, which would have
been wrong on macOS and Linux; and the installer stopped short of any file
migration.

One finding was **rejected**: "never create the settings file empty — copy the
example into it." A file that every shell sources should not arrive carrying a
placeholder hostname nobody chose. It is created with a comment header
explaining what it is for, and no code.

## License

MIT — see [LICENSE](LICENSE). It is configuration and documentation: take it,
change it, no attribution burden beyond keeping the notice.
