#!/usr/bin/env zsh
# 🌿 git — everyday commands, branch naming, worktrees, pull requests.

get_git_info() {
    th_head "🌿" "Git"
    th_row "Where am I:"        "git status -sb"
    th_note "branch and short status in one line"
    th_row "What changed:"      "git diff            (unstaged)"
    th_row ""                   "git diff --staged   (what a commit would contain)"
    th_row "Stage and commit:"  "git add -A && git commit -m \"feat: ...\""
    th_row "Undo last commit:"  "git reset --soft HEAD~1"
    th_note "keeps the changes, drops the commit"
    th_row "Discard a file:"    "git restore {path}"
    th_note "unrecoverable — there is no reflog for uncommitted work"
    th_row "Sync with remote:"  "git fetch && git rebase origin/main"
    th_row "Amend and repush:"  "git commit --amend && git push --force-with-lease"
    th_note "--force-with-lease, never --force: it refuses if someone pushed since your last fetch"
    print -r --
    get_git_branch_info
    get_git_worktree_info
    get_git_pr_info
}

get_git_branch_info() {
    th_sub "🌱" "Branches and commit messages"
    th_row "Never commit to main." "every change is a branch, merged by a PR"
    th_row "Branch format:"      "{type}/{kebab-case-slug}   (<= 6 words)"
    th_row "Types:"              "feat/  fix/  hotfix/  docs/  chore/  refactor/"
    th_row "Examples:"           "feat/slack-run-tests"
    th_row ""                    "fix/mount-fails-when-offline"
    th_row "Commit messages:"    "Conventional Commits — feat: fix: docs: chore:"
    th_note "feat(share): retry the mount once on timeout"
    th_note "a breaking change is feat(api)!: ..."
    th_row "List branches:"      "git branch -a --sort=-committerdate | head"
    th_note "read this BEFORE starting: you may already have a branch for it"
}

get_git_worktree_info() {
    th_sub "🌳" "Worktrees — one feature, one branch, one worktree, one PR"
    th_text "A worktree is a second working directory sharing one .git. Two"
    th_text "features can be edited at once with no stashing and no branch"
    th_text "switching underneath live work."
    print -r --
    th_row "Create:"             "git worktree add ../{repo}-{slug} -b feat/{slug}"
    th_note "new directory, new branch, checked out and ready"
    th_row "From a branch:"      "git worktree add ../{repo}-{slug} feat/{slug}"
    th_row "Detached:"           "git worktree add --detach ../{repo}-check origin/main"
    th_note "for a build or a bisect, with no branch bound to it"
    th_row "List:"               "git worktree list"
    th_row "Remove when merged:" "git worktree remove ../{repo}-{slug}"
    th_row ""                    "git branch -d feat/{slug}"
    th_row "Prune stale entries:" "git worktree prune"
    print -r --
    th_text "The six rules that make it work:"
    th_text "  1. Confirm where you are before editing:"
    th_text "     git rev-parse --show-toplevel && git branch --show-current"
    th_text "  2. Build, test and commit INSIDE the worktree. Never edit a"
    th_text "     feature's files from the main checkout."
    th_text "  3. A branch can be checked out in one worktree at a time —"
    th_text "     'already used by worktree' is that rule, not an error."
    th_text "  4. node_modules and .venv are per-worktree. A new worktree"
    th_text "     needs its own npm install or uv sync."
    th_text "  5. A worktree isolates EDITING, not merge conflicts. Rebase on"
    th_text "     origin/main before opening the PR and resolve there."
    th_text "  6. Remove it after the merge. A leftover worktree is what makes"
    th_text "     finished work look live to the next person."
}

get_git_pr_info() {
    th_sub "🔀" "Pull requests (gh)"
    th_row "Install:"            "brew install gh && gh auth login"
    th_row "Who am I:"           "gh api user -q .login"
    th_note "the honest check — under the wrong account 'gh pr list' prints"
    th_note "nothing and exits 0, so an existing PR looks absent"
    th_row "Switch account:"     "gh auth switch --user {name}"
    print -r --
    th_text "The loop:"
    th_row "  1. Branch:"        "git worktree add ../{repo}-{slug} -b feat/{slug}"
    th_row "  2. Commit:"        "git add -A && git commit -m \"feat: ...\""
    th_row "  3. Push:"          "git push -u origin feat/{slug}"
    th_row "  4. Open:"          "gh pr create --fill"
    th_note "or --title \"feat: ...\" --body \"...\" --draft"
    th_row "  5. Watch checks:"  "gh pr checks {n}"
    th_row ""                    "gh pr view {n} --json statusCheckRollup,mergeStateStatus"
    th_note "pr view takes --json; older gh has no --json on pr checks, and a"
    th_note "wait loop built on it never exits"
    th_row "  6. Merge:"         "gh pr merge {n} --squash --delete-branch"
    th_row "  7. Clean up:"      "git worktree remove ../{repo}-{slug}"
    print -r --
    th_text "Reading and reviewing:"
    th_row "  List open PRs:"    "gh pr list          (--author @me for yours)"
    th_row "  Read one:"         "gh pr view {n}      (--web to open a browser)"
    th_row "  Its diff:"         "gh pr diff {n}"
    th_row "  Check out locally:" "gh pr checkout {n}"
    th_row "  Comment:"          "gh pr comment {n} --body \"...\""
    th_row "  Approve:"          "gh pr review {n} --approve"
    print -r --
    th_text "One logical change per PR. Don't bundle unrelated work — a big"
    th_text "feature splits into stacked PRs (schema, then API, then UI), each"
    th_text "reviewable alone. Bug fixes lead with the failing test."
    print -r --
    th_text "A red check that ran nothing:"
    th_row "  Inspect the jobs:" "gh api repos/{owner}/{repo}/actions/runs/{id}/jobs \\"
    th_row ""                    "  -q '.jobs[] | \"\\(.name) runner=\\(.runner_name)\"'"
    th_note "an empty runner name means no runner was ever allocated, so the"
    th_note "red says nothing about your branch — usually billing, not code"
}
