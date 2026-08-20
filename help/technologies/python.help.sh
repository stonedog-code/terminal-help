#!/usr/bin/env zsh
# 🐍 Python — the toolchain is uv. Do not use pip, venv or pyenv here.
# TH_TOPIC: python
# TH_EMOJI: 🐍
# TH_DESC:  Python — uv, virtualenvs, uvicorn
# TH_ALSO:  get_uv_help | 📦 | uv: projects, dependencies, venvs
# TH_ALSO:  get_uvicorn_help | ⚡ | uvicorn and FastAPI launch lines

_th_help_python() {
    th_head "🐍" "Python"
    th_row "Install Python:"     "brew install python@3.13      (macOS)"
    th_row ""                    "sudo apt install python3      (Debian/Ubuntu)"
    th_row "Install uv:"         "brew install uv"
    th_row ""                    "curl -LsSf https://astral.sh/uv/install.sh | sh"
    th_note "uv installs and manages Python itself, so the system Python"
    th_note "does not have to be the right version — or exist at all"
    print -r --
    get_uv_help
    get_uvicorn_help
}

get_uv_help() {
    th_sub "📦" "uv"
    th_row "New project:"        "uv init"
    th_note "writes pyproject.toml and .python-version"
    th_row "Add dependencies:"   "uv add \"fastapi[standard]\" uvicorn pytest"
    th_note "updates pyproject.toml and uv.lock together"
    th_row "Add dev deps:"       "uv add --dev pytest ruff mypy"
    th_row "Install from lock:"  "uv sync"
    th_note "installs every pinned package into .venv"
    th_row "Run in the venv:"    "uv run python {app.py}"
    th_note "never activate a venv by hand"
    th_row "Run a tool:"         "uvx ruff check .    (no project install)"
    th_row "Manage interpreters:" "uv python install 3.12 3.13"
    th_row ""                    "uv python pin 3.13"
}

get_uvicorn_help() {
    th_sub "⚡" "Uvicorn"
    th_row "What it is:"         "ASGI web server for Python (uvloop + httptools)"
    th_row "Development:"        "uv run uvicorn app:app --reload --port 8000"
    th_row "Production:"         "uv run uvicorn app:app --host 0.0.0.0 --port 8000 --workers 4"
    th_row "FastAPI shortcut:"   "uv run fastapi dev app.py"
    th_note "built on Uvicorn, with reload already on"
}
