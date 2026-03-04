#!/usr/bin/env bash
set -euo pipefail

# Lightweight diagnostics for common developer tools expected after setup.
# This script is intentionally non-fatal and prints what is available.
echo "starship: $(starship --version 2>/dev/null || echo 'not found')"
echo "pyenv: $(pyenv --version 2>/dev/null || echo 'not found')"
echo "python3: $(command -v python3 || echo 'not found') $(python3 --version 2>/dev/null || true)"
echo "nano: $(nano --version 2>/dev/null | awk 'NR==1 {print $0}' || echo 'not found')"
echo "zsh: $(zsh --version 2>/dev/null || true)"
