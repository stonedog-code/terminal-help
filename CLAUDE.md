# terminal-help

A shell reference that loads with your shell. zsh edition in `terminal-help.zsh`
+ `lib/*.zsh`; PowerShell edition in `powershell/TerminalHelp.ps1`. Nothing
host-specific ships here — see the README for the `~/.zshrc-user.sh` contract.

**The gate is `bash scripts/check-syntax.sh` plus
`bash scripts/test-user-file-loads.sh` (and its `--self-check`).** There are no tests and there
cannot usefully be any: this code prints a cheat-sheet into an interactive
terminal. What CI guarantees is that nothing is syntactically broken, which
matters more than usual because `lib/*.zsh` is sourced from a real person's
`~/.zshrc` — a syntax error breaks their shell, not a test run.

