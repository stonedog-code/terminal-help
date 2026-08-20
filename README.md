# 🧰 terminal-help

A reference that lives in your shell. `get_help` prints the index; every
section is a command away — git worktrees, the `gh` pull-request loop, `uv`,
whatever you add yourself.

It runs on **macOS**, **Linux** (zsh) and **Windows** (PowerShell), and it
prints exactly one line when a shell starts:

```
🧰 terminal-help v0.7.0 · get_help
```

Everything host-specific — your servers, your shares, your aliases — lives in
`~/.zshrc-user.sh` (or `profile-user.ps1` beside your `$PROFILE`), a file this
project **creates once and then never opens again**. Nothing personal is in the
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
🧰 terminal-help v0.7.0
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
| `~/.terminal-help/` | the runtime: `terminal-help.zsh`, `lib/*.zsh`, `VERSION` | replaced |
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

**On Windows, run the PowerShell installer instead** (`install.sh` can only
reach your `$PROFILE` from WSL, and will print this command if it cannot):

```powershell
powershell -ExecutionPolicy Bypass -File .\powershell\install.ps1
```

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

**PowerShell** is the native route and needs no WSL:

```powershell
winget install --id Microsoft.PowerShell        # PowerShell 7; 5.1 works but is older
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
New-Item -ItemType File -Path $PROFILE -Force   # if you have no profile yet
notepad $PROFILE
```

Add these two lines:

```powershell
$env:TH_HOME = "C:\src\terminal-help"
. "$env:TH_HOME\powershell\TerminalHelp.ps1"
```

Reload with `. $PROFILE`. Without the execution-policy change a profile
silently does not load, which looks exactly like a broken install.

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

Running both WSL and PowerShell? Install both editions — `./install.sh` inside
WSL and `install.ps1` in PowerShell. The command names are identical, so
`get_git_info` works in either.
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

`cat zshrc-user.sh.example` in the clone for a worked version of both.

**PowerShell works the same way**, with the file beside your `$PROFILE` —
`profile-user.ps1`, resolved from `$PROFILE` rather than hardcoded, so it lands
in `Documents\PowerShell` on Windows and `~/.config/powershell` on macOS and
Linux. The hooks there are `Show-UserInfo` and `Invoke-UserOnLoad`.

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
| On every new shell | one line: `🧰 terminal-help v0.7.0 · get_help` |
| Plus | whatever *your* `user_on_load` chooses to print — nothing, by default |
| Everything else | only when you ask for it by name |

Silence even the version line with `TH_QUIET=1` (put it in `~/.zshenv`, or
`$env:TH_QUIET = 1` for PowerShell). Note that this also skips `user_on_load`.

---

## The sections

| Command | |
|---|---|
| `get_help` | ❓ the index (alias: `help_me`) |
| `get_versions` | 📋 OS, shell, python, uv, git, gh, node, brew |
| `get_git_info` | 🌿 git — the three below, in order |
| `get_git_branch_info` | 🌱 branch naming, Conventional Commits |
| `get_git_worktree_info` | 🌳 worktrees, and the six rules that make them work |
| `get_git_pr_info` | 🔀 the `gh` pull-request loop, reviewing, red checks |
| `get_python_info` | 🐍 Python — with the two below |
| `get_uv_info` | 📦 `uv`: projects, dependencies, venvs |
| `get_uvicorn_info` | ⚡ uvicorn and FastAPI launch lines |
| `get_mac_info` | 🍎 Homebrew, shares, Finder, clipboard |
| `get_linux_info` | 🐧 installing zsh, packages, services, ports |
| `get_windows_info` | 🪟 PowerShell, winget, WSL, zsh on Windows |
| `get_user_info` | 🔒 yours, from `~/.zshrc-user.sh` |

---

## Adding a section

One file per topic in `lib/`, loaded automatically — no registration step:

```zsh
# lib/docker.zsh
get_docker_info() {
    th_head "🐳" "Docker"
    th_row  "Build:"  "docker build -t {name} ."
    th_note "--platform linux/amd64 when the target is not an M-series Mac"
}
```

Then add a row to `get_help` in `lib/help.zsh`. The value of a section is in
the `↳` notes: anyone can look up `docker build`; what is worth writing down is
the flag whose absence costs an hour.

One-off personal sections do not need a file in `lib/` at all — define them in
`~/.zshrc-user.sh` as `get_user_info` and they appear under 🔒 in `get_help`.

For the PowerShell edition, add the same function to
`powershell\TerminalHelp.ps1` and a `Set-Alias` next to the others. The two
editions are deliberately separate files — that means content lives twice, and
a section added to one is missing from the other until you copy it.

---

## Layout

```
terminal-help/
├── terminal-help.zsh          the loader — resolves paths, loads lib/, defines th_source_user
├── lib/
│   ├── ui.zsh                 colour, emoji and layout helpers; everything else uses them
│   ├── help.zsh               ❓ the index and the startup banner
│   ├── git.zsh                🌿 git, branches, worktrees, PRs
│   ├── python.zsh             🐍 python, uv, uvicorn
│   ├── mac.zsh                🍎 macOS
│   ├── linux.zsh              🐧 Linux
│   ├── windows.zsh            🪟 Windows and PowerShell
│   └── versions.zsh           📋 what is installed
├── powershell/
│   ├── TerminalHelp.ps1       the PowerShell edition, same commands
│   ├── install.ps1            adds the block to $PROFILE
│   └── profile-user.ps1.example   a worked example of ~/…/profile-user.ps1
├── zshrc-user.sh.example      a worked example of ~/.zshrc-user.sh
├── install.sh                 the multi-select installer (copies to ~/.terminal-help)
├── .zshrc                     an example ~/.zshrc, if you would rather symlink one
├── VERSION
└── LICENSE
```

---

## Colour and emoji

256-colour ANSI, one palette in `lib/ui.zsh`. Colour is decided **per call**,
not once at load, so `get_git_info | less` and `get_git_info > notes.txt` come
out clean rather than full of escape codes.

- `NO_COLOR=1` or `TH_NO_COLOR=1` turns it off ([no-color.org](https://no-color.org)).
- Emoji need a font that has them. macOS Terminal, iTerm2, Windows Terminal and
  most Linux terminals are fine; the legacy Windows console host (`conhost`) is
  not — use Windows Terminal, or set `TH_NO_COLOR=1` and accept the tofu.

---

## Verified

Run against real interpreters, not eyeballed:

- **zsh 5.9** and **PowerShell 7.4** — every section rendered without error in
  both editions, and a new interactive shell printing exactly one line.
- **Colour, in four directions** — escapes present on a tty; absent when piped,
  absent under `NO_COLOR=1`, absent under `TERM=dumb`. Worth stating, because
  the first implementation resolved colours inside `$( )`, where stdout is a
  pipe: every colour came back empty and the output looked like a deliberate
  monochrome theme. Checking only that it *rendered* would have missed it.
- **`install.sh`, interactively, on a pty** — the menu answered with `1`, `4`
  and an empty line. This is where the first release broke: the menu was
  written to stdout, which the caller captures, so every word of it came back
  as a selection (`⚠ unknown target: Which`). Only `--targets` had been
  exercised, and that path skips the menu entirely — the test was green because
  it never ran the broken code. The menu now goes to stderr.
- **`install.sh`** — installs into an existing `~/.zshrc`, a re-run leaves one
  block rather than two, and `--uninstall` restores the original file byte for
  byte (`cmp`, not inspection). Same three for `install.ps1` against a real
  `$PROFILE`.
- **The upgrade path** — with a populated `~/.zshrc-user.sh` in place, a re-run
  leaves its md5 **and its mtime** unchanged and creates no `.bak` beside it.
  Both editions.
- **Declining the prompt** — `~/.zshrc` byte-identical afterwards, no settings
  file created, no backup left behind.
- **Installed, then the clone deleted** — the decisive test for v0.7.0. After
  `rm -rf` on the source clone, a real zsh and a real `pwsh` both still print
  the version line, load `~/.zshrc-user.sh`, run `user_on_load`, and render
  `get_user_info`. Nothing outside `$HOME` is referenced at runtime.
- **Both live rc paths** — a real interactive zsh started through the installed
  block, and through the symlinked `.zshrc`, with hooks, aliases and
  `user_on_load` all working. Same for a real `pwsh` session through the
  installed `$PROFILE`. That last one caught a scope bug: dot-sourcing the
  user file *inside a function* traps the user's functions in that function's
  scope, so they vanish when it returns. PowerShell loads it at script scope
  now; the comment in `TerminalHelp.ps1` explains why.
- **The private half** — hooks load from `~/.zshrc-user.sh` /
  `profile-user.ps1`, `get_help` distinguishes four states (not loaded, empty,
  content but no hooks, hooks defined), and `th_source_user` is idempotent:
  called three times, `user_on_load` still runs once.
- **Nothing shipped is specific to one machine.** The sections describe tools
  anyone has — git, uv, brew, winget, systemd — not one person's hosts, shares
  or workflow. Anything that only made sense for one setup was removed rather
  than genericised into vagueness.

**Not verified:** macOS itself — there is no Mac in the loop, so `mount_smbfs`,
`diskutil` and `sw_vers` are unexercised; Windows PowerShell 5.1 (7.4 only);
and emoji rendering in any particular terminal.

---

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
