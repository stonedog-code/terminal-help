#!/usr/bin/env zsh
# TH_TOPIC: homebrew
# TH_EMOJI: 🍺
# TH_DESC:  Homebrew — installing, upgrading, and the bits that bite

_th_help_homebrew() {
    th_head "🍺" "Homebrew"
    th_row "Install it:"        "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    th_note "on Apple silicon it lands in /opt/homebrew, on Intel in /usr/local —"
    th_note "which is why a script that hardcodes one path breaks on the other"
    th_row "Put it on PATH:"    "eval \"\$(/opt/homebrew/bin/brew shellenv)\""
    th_note "that line belongs in ~/.zshrc-user.sh, not ~/.zshrc"
    th_row "Where is it:"       "brew --prefix    ·    brew --prefix {formula}"
    print -r --

    th_sub "📦" "Everyday"
    th_row "Install:"           "brew install {formula}"
    th_row "An app:"            "brew install --cask {app}      (GUI apps)"
    th_row "Search:"            "brew search {text}"
    th_row "What is it:"        "brew info {formula}"
    th_row "Remove:"            "brew uninstall {formula}"
    th_row "What do I have:"    "brew list --versions"
    th_row "Only what I asked for:" "brew leaves"
    th_note "leaves = things you installed on purpose, not their dependencies —"
    th_note "the list worth putting in a Brewfile"

    th_sub "⬆️" "Upgrading, and why it surprises people"
    th_row "Refresh the index:" "brew update"
    th_row "Upgrade everything:" "brew upgrade"
    th_row "Upgrade one thing:" "brew upgrade {formula}"
    th_note "brew upgrade with no argument upgrades EVERYTHING installed, which"
    th_note "on a work machine can move a database or a language runtime you"
    th_note "did not mean to touch. Name the formula when you mean one thing."
    th_row "Hold something back:" "brew pin {formula}    ·    brew unpin {formula}"
    th_row "See what would move:" "brew outdated"
    th_row "Casks too:"         "brew upgrade --cask"

    th_sub "🧹" "Space and cleanliness"
    th_row "Old versions:"      "brew cleanup -n     (dry run — always first)"
    th_row ""                   "brew cleanup"
    th_row "How much is this:"  "du -sh \$(brew --prefix)"
    th_row "Health check:"      "brew doctor"
    th_note "brew doctor complains about things that are usually fine; read it"
    th_note "as a list of suspects, not a list of faults"
    th_row "Autoremove orphans:" "brew autoremove"

    th_sub "📋" "Reproducing a machine"
    th_row "Write a Brewfile:"  "brew bundle dump --describe --force"
    th_row "Install from one:"  "brew bundle install"
    th_row "Check it matches:"  "brew bundle check"
    th_row "Remove anything else:" "brew bundle cleanup --force"
    th_note "a Brewfile in a dotfiles repo is the shortest honest answer to"
    th_note "\"how do I set up a new Mac\""

    th_sub "🔧" "Services and taps"
    th_row "Start something:"   "brew services start postgresql@16"
    th_row "What is running:"   "brew services list"
    th_row "Restart / stop:"    "brew services restart {name}    ·    stop"
    th_row "Add a tap:"         "brew tap {user}/{repo}"
    th_note "a tap is a third-party formula source — it is someone else's"
    th_note "build script running on your machine, so know whose"

    th_sub "🩹" "When it goes wrong"
    th_row "Command not found after install:" "hash -r    (rehash the PATH cache)"
    th_row "Wrong architecture:" "file \$(brew --prefix)/bin/{cmd}"
    th_note "an Intel binary under Rosetta on Apple silicon is the usual cause"
    th_note "of \"bad CPU type\" — check which brew prefix you are actually using"
    th_row "Two brews at once:" "which -a brew"
    th_note "/usr/local and /opt/homebrew both on PATH is how you end up with"
    th_note "two copies of a tool and one mysterious version"
    th_row "Roll a formula back:" "brew uninstall {f} && brew install {f}@{version}"
    th_note "only if a versioned formula exists — brew does not keep old builds"
}

# The two names people actually type. th_info_twin gives it get_brew_info, so
# all four spellings work: brew/homebrew × help/info.
get_brew_help() { get_homebrew_help "$@" }
th_info_twin get_brew_help
