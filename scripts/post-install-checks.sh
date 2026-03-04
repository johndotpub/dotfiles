#!/usr/bin/env bash
set -euo pipefail

echo "starship: $(starship --version 2>/dev/null || echo 'not found')"
echo "pyenv: $(pyenv --version 2>/dev/null || echo 'not found')"
echo "python: $(command -v python || echo 'not found') $(python --version 2>/dev/null || true)"
echo "zsh: $(zsh --version 2>/dev/null || true)"
