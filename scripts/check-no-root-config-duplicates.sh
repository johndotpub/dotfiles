#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Canonical shell configs live under skel/default.
for path in ".zshrc" ".bashrc" ".bash_profile" ".profile"; do
  if [[ -e "${REPO_DIR}/${path}" || -L "${REPO_DIR}/${path}" ]]; then
    echo "Unexpected repo-root shell config: ${path}" >&2
    echo "Keep canonical copies in skel/default/ only." >&2
    exit 1
  fi
done

echo "No duplicate repo-root shell config files detected."
