#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"
setup_brew_env

brew install starship || true

mkdir -p "${HOME}/.config"
if [[ -f "${HOME}/.config/starship.toml" ]]; then
  echo "Keeping existing ${HOME}/.config/starship.toml"
  exit 0
fi

cat > "${HOME}/.config/starship.toml" <<'EOF'
# Default: follow detection rules (no forced home python)
[character]
success_symbol = "[✔](bold green) "
EOF
