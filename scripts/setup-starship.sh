#!/usr/bin/env bash
set -euo pipefail

if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew install starship || true

mkdir -p "${HOME}/.config"
cat > "${HOME}/.config/starship.toml" <<'EOF'
# Default: follow detection rules (no forced home python)
[character]
success_symbol = "[✔](bold green) "
EOF
