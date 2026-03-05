#!/usr/bin/env bash
set -euo pipefail

# Locate this script so sourcing helper works regardless of caller cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"

# Load brew env before invoking brew subcommands.
setup_brew_env

# Keep this script intentionally small: install tooling only.
# Shell initialization is handled by skel/default/.zshrc.
had_errors=0
if ! brew install pyenv pyenv-virtualenv; then
  echo "Warning: brew failed to install/upgrade pyenv tooling." >&2
  had_errors=1
fi

# Plugin wiring is handled in skel/default/.zshrc using the default OMZ pyenv plugin.

if [[ "$had_errors" -ne 0 ]]; then
  exit 1
fi
