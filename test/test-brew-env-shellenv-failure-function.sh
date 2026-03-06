#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Keep PATH minimal so no real brew fallback path can be discovered.
export PATH="/usr/bin:/bin"
unset HOMEBREW_PREFIX || true

# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"

# Simulate a callable brew command that fails for shellenv.
brew() {
  if [[ "${1:-}" == "shellenv" ]]; then
    return 1
  fi
  return 1
}

if setup_brew_env; then
  echo "setup_brew_env unexpectedly succeeded when brew shellenv failed"
  exit 1
fi

echo "brew shell function failure path test passed."
