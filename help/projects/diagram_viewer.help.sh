#!/usr/bin/env zsh
# 📐 diagram-viewer — FastAPI serving the Mermaid .mer files in diagrams/.
# TH_TOPIC: diagram_viewer
# TH_EMOJI: 📐
# TH_DESC:  diagram-viewer — uv + FastAPI serving Mermaid .mer diagrams
# TH_RELATED: python

_th_help_diagram_viewer() {
    th_head "📐" "diagram-viewer"
    th_text "A FastAPI app serving the Mermaid diagrams in diagrams/: an"
    th_text "index, and a page per file rendered in the browser. Add one"
    th_text "by dropping a .mer file in — no code to edit, no restart."

    th_sub "📍" "Where it lives"
    th_row "GitHub:"          "stonedog-code/diagram-viewer  (public)"
    th_row "Clone:"           "gh repo clone stonedog-code/diagram-viewer"
    th_note "the README still names the old nehsa-net owner"
    th_row "npm / PyPI:"      "neither — an app, not a library"

    th_sub "⚡" "Install and run"
    th_row "Serve on :8000:"  "bash run.sh"
    th_row "Another port:"    "bash run.sh serve --port 9000"
    th_row "The gate:"        "bash run.sh test"
    th_row "One tier:"        "bash run.sh test tests/e2e"
    th_note "run.sh builds the env, then starts the server"
    th_warn "bash run.sh, not ./run.sh"
    th_note "the executable bit may not survive a share"

    th_sub "🧱" "Dependencies"
    th_row "The only one:"    "uv"
    th_note "curl -LsSf https://astral.sh/uv/install.sh | sh or"
    th_note "brew install uv — it lands in ~/.local/bin"
    th_row "Python:"          ".python-version pins 3.12"
    th_note "uv downloads it — no system Python needed"

    # Summary ends here. Everything below is the --detailed view.
    th_detail || return

    th_sub "🪤" "bash run.sh, not ./run.sh"
    th_text "Both work on a normal clone, but the executable bit does"
    th_text "not always survive a network share, and bash works either"
    th_text "way."

    th_sub "🖥" "A checkout shared between two machines"
    th_text "Skip this unless the working tree lives on a share a Mac"
    th_text "and a Linux box both mount. A .venv is NOT portable — it"
    th_text "holds one architecture's compiled extensions, an absolute"
    th_text "shebang in every console script, and a bin/python symlink"
    th_text "into that machine's toolchain."
    th_row "The error:"       "Failed to spawn: uvicorn — No such file..."
    th_warn "That message names the wrong file"
    th_note "uvicorn is right there; its shebang points at"
    th_note ".venv/bin/python, that symlink targets an"
    th_note "interpreter the other machine lacks, and execve"
    th_note "reports a missing shebang interpreter as ENOENT"
    th_note "AGAINST THE SCRIPT. So it reads as \"uvicorn is"
    th_note "not installed\" — and uv sync does not fix it,"
    th_note "because site-packages is the wrong platform's"
    th_note "binaries too."
    th_row "The fix, built in:" "run.sh sources scripts/uv-env.sh"
    th_note "macOS gets .venv-macos, everything else .venv, so"
    th_note "the two never collide. For a bare uv run on a Mac,"
    th_note "export the same:"
    th_row ""                 "export UV_PROJECT_ENVIRONMENT=.venv-macos"

    th_sub "🧜" "Adding a diagram"
    th_text "Drop a .mer file into diagrams/. The directory is scanned"
    th_text "per request, so a new file appears on the next page load"
    th_text "even without --reload."
    th_row "The slug:"        "architecture.mer -> /diagram/architecture"
    th_row "Optional header:" "%% title: Architecture Flowchart"
    th_row ""                 "%% description: services and pipelines"
    th_note "Mermaid treats %% as a comment, so the file stays"
    th_note "valid Mermaid source you can paste into any other"
    th_note "tool only the LEADING comment block is read as"
    th_note "metadata — the first line that is not %% key:"
    th_note "value ends it, so a note inside the diagram stays"
    th_note "in the diagram with no title, the filename is used"

    th_sub "🔍" "Reading a wide one"
    th_row "Zoom:"            "- / + step, 10% to 400%"
    th_row "Reset / Fit:"     "0  /  F"
    th_row "Pan:"             "drag, anywhere in the diagram area"
    th_note "a page opens FITTED to width, not at 100% — a"
    th_note "diagram that opens scrolled off the right edge"
    th_note "reads as broken. Once you zoom, it stops re-"
    th_note "fitting itself."

    th_sub "💡" "Quick tips"
    th_row "The tiers:"       "unit (loader) · integration (routes) · e2e"
    th_note "run.sh test fetches the Chromium build the browser"
    th_note "tier drives, then runs pytest. Playwright only"
    th_note "downloads a build it lacks, so after the first run"
    th_note "that call makes no network request at all."
    th_row "Where logic is:"  "loader.py — no HTTP, no HTML"
    th_note "app.py is the two routes and nothing else, which"
    th_note "is what makes the unit tier possible"
}
