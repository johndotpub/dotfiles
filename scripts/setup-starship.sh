#!/usr/bin/env bash
set -euo pipefail

# Resolve absolute script path so helper sourcing is robust.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"

# Ensure brew environment is loaded for this shell.
setup_brew_env

# Install/upgrade starship through brew.
had_errors=0
if ! brew install starship; then
  echo "Warning: brew failed to install/upgrade starship." >&2
  had_errors=1
fi

# Resolve config locations once so behavior is consistent.
mkdir -p "${HOME}/.config"
TARGET="${HOME}/.config/starship.toml"
FALLBACK="${SCRIPT_DIR}/../skel/default/.config/starship.toml"
skip_config=0

# Preserve user-managed config by default.
if [[ -f "$TARGET" ]]; then
  echo "Keeping existing ${TARGET}"
  skip_config=1
fi

# Prefer official preset command, then fall back to bundled template.
if [[ "$skip_config" -eq 0 ]]; then
  if command -v starship >/dev/null 2>&1 && starship preset --help >/dev/null 2>&1; then
    starship preset tokyo-night -o "$TARGET"
    echo "Configured starship preset: tokyo-night"
  elif [[ -f "$FALLBACK" ]]; then
    cp -Rp "$FALLBACK" "$TARGET"
    echo "Configured fallback tokyo-night starship.toml"
  else
    echo "Could not configure starship preset automatically."
    had_errors=1
  fi
fi

if [[ "$had_errors" -ne 0 ]]; then
  exit 1
fi
