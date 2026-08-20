# 🧰 terminal-help

A reference that lives in your shell. `get_help` prints the index; every
section is a command away — git worktrees, the `gh` pull-request loop, `uv`,
whatever you add yourself.

It runs on **macOS**, **Linux** (zsh) and **Windows** (PowerShell), and it
prints exactly one line when a shell starts:

```
🧰 terminal-help v0.3.0 · get_help
```

Everything host-specific — your servers, your shares, your aliases — lives in
`user.sh` (or `powershell\user.ps1`), which is **gitignored and never
committed**. That is what makes the repository publishable.

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
🧰 terminal-help v0.3.0
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

- adds **one marked block** to the `~/.zshrc` or `$PROFILE` you already have —
  it never overwrites your config, and re-running replaces its own block
  instead of appending a second one;
- backs the file up first (`.terminal-help.bak`);
- tells you if zsh is missing, or is installed but is not your login shell;
- offers to create your private `user.sh` from the example.

Non-interactive, for a setup script:

```sh
./install.sh --targets mac,linux,windows --yes
./install.sh --uninstall              # removes the block, keeps the clone
```

Then open a new terminal and type `get_help`.

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

## 🔒 The private half: `user.sh`

The repository contains no hostnames, no usernames and no personal aliases.
It defines four hook names and calls them if they exist; everything behind
those hooks is yours and stays on your machine.

```sh
cp user.sh.example user.sh        # gitignored
chmod 600 user.sh
$EDITOR user.sh
```

| Hook | Called when | Typical contents |
|---|---|---|
| `connect_work` | you type it | mount a share, open a tunnel, start a VPN |
| `disconnect_work` | you type it | the reverse |
| `get_user_info` | you type it | your own reference sections — internal hosts, runbooks |
| `user_on_load` | **every new shell** | the only thing besides the version line that may print |

PowerShell uses the same four under PowerShell names, in
`powershell\user.ps1`: `Connect-Work`, `Disconnect-Work`, `Show-UserInfo`,
`Invoke-UserOnLoad`.

With no `user.sh`, `connect_work` still exists — it prints how to create one,
rather than `command not found`, which reads like a broken install.

Your sections get the same styling helpers the built-in ones use, so they do
not look bolted on:

```zsh
get_user_info() {
    th_head "🔒" "My machines"
    th_row  "Build box:"  "ssh build-01.internal"
    th_note "the jump host is only reachable on the VPN"
    th_sub  "🚀" "Deploys"
    th_row  "Staging:"    "./deploy.sh staging"
}
```

`th_head`, `th_sub`, `th_row`, `th_note`, `th_text`, `th_warn`, `th_ok` — and
in PowerShell, `Write-ThHead`, `Write-ThSub`, `Write-ThRow`, `Write-ThNote`,
`Write-ThText`, `Write-ThWarn`, `Write-ThOk`.

**No passwords in `user.sh`.** macOS keeps share credentials in the login
keychain and Windows in Credential Manager, both after the first successful
connection. A password on disk is a plaintext credential with no expiry that
every backup copies.

Keep `user.sh` somewhere else — outside the clone entirely — by exporting
`TH_USER_FILE` before the source line, or by putting it at
`~/.config/terminal-help/user.sh`, which is checked automatically.
PowerShell uses `$env:TH_USER_FILE` the same way.

**Check what git can see before your first push:**

```sh
git ls-files | grep user
# user.sh.example       <- the placeholder, and no bare user.sh. Good.
```

---

## What prints, and when

| | |
|---|---|
| On every new shell | one line: `🧰 terminal-help v0.3.0 · get_help` |
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
| `get_user_info` | 🔒 yours, from `user.sh` |

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

For the PowerShell edition, add the same function to
`powershell\TerminalHelp.ps1` and a `Set-Alias` next to the others. The two
editions are deliberately separate files — that means content lives twice, and
a section added to one is missing from the other until you copy it.

---

## Layout

```
terminal-help/
├── terminal-help.zsh          the loader — resolves paths, loads lib/, then user.sh
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
│   └── user.ps1.example       → copy to user.ps1  (gitignored)
├── user.sh.example            → copy to user.sh   (gitignored)
├── install.sh                 the multi-select installer
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
- **`install.sh`** — installs into an existing `~/.zshrc`, a re-run leaves one
  block rather than two, and `--uninstall` restores the original file byte for
  byte (`cmp`, not inspection). Same three for `install.ps1` against a real
  `$PROFILE`.
- **The private half** — hooks load from `user.sh`/`user.ps1`, `get_help` grows
  its 🔒 section, and both files are confirmed ignored by git.

**Not verified:** macOS itself — there is no Mac in the loop, so `mount_smbfs`,
`diskutil` and `sw_vers` are unexercised; Windows PowerShell 5.1 (7.4 only);
and emoji rendering in any particular terminal.

---

## License

MIT — see [LICENSE](LICENSE). It is configuration and documentation: take it,
change it, no attribution burden beyond keeping the notice.
