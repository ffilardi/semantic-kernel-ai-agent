#!/usr/bin/env bash
set -euo pipefail

echo "[devcontainer] Upgrading pip..."
python -m pip install --upgrade pip

echo "[devcontainer] Searching for requirements.txt files under src/*"
shopt -s nullglob
req_files=( src/*/requirements.txt )

if [ ${#req_files[@]} -eq 0 ]; then
  echo "[devcontainer] No requirements.txt files found under src/*"
else
  for f in "${req_files[@]}"; do
    echo "[devcontainer] Installing $f"
    pip install -r "$f"
  done
fi

echo "[devcontainer] Dependency installation complete."