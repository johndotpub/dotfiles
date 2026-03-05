#!/usr/bin/env bash
set -euo pipefail

# Resolve absolute script path so helper sourcing is robust.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"

# Ensure brew environment is loaded for this shell.
setup_brew_env

# Install/upgrade starship through brew.
brew install starship || true

# Resolve config locations once so behavior is consistent.
mkdir -p "${HOME}/.config"
TARGET="${HOME}/.config/starship.toml"
FALLBACK="${SCRIPT_DIR}/../skel/default/.config/starship.toml"

# Preserve user-managed config by default.
if [[ -f "$TARGET" ]]; then
  echo "Keeping existing ${TARGET}"
  exit 0
fi

# Prefer official preset command, then fall back to bundled template.
if command -v starship >/dev/null 2>&1 && starship preset --help >/dev/null 2>&1; then
  starship preset tokyo-night -o "$TARGET"
  echo "Configured starship preset: tokyo-night"
elif [[ -f "$FALLBACK" ]]; then
  cp -Rp "$FALLBACK" "$TARGET"
  echo "Configured fallback tokyo-night starship.toml"
else
  echo "Could not configure starship preset automatically."
fi
