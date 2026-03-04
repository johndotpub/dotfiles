#!/usr/bin/env bash
set -euo pipefail

if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew install pyenv pyenv-virtualenv || true

if ! grep -q 'pyenv init' "${HOME}/.zshrc" 2>/dev/null; then
  cat >> "${HOME}/.zshrc" <<'EOF'

# pyenv init
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi
EOF
fi
