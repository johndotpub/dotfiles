#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"
setup_brew_env

brew install starship || true

mkdir -p "${HOME}/.config"
TARGET="${HOME}/.config/starship.toml"
FALLBACK="${SCRIPT_DIR}/../skel/default/.config/starship.toml"

if [[ -f "$TARGET" ]]; then
  echo "Keeping existing ${TARGET}"
  exit 0
fi

if command -v starship >/dev/null 2>&1 && starship preset --help >/dev/null 2>&1; then
  starship preset tokyo-night -o "$TARGET"
  echo "Configured starship preset: tokyo-night"
elif [[ -f "$FALLBACK" ]]; then
  cp -a "$FALLBACK" "$TARGET"
  echo "Configured fallback tokyo-night starship.toml"
else
  echo "Could not configure starship preset automatically."
fi
