#!/usr/bin/env bash
set -euo pipefail

# Post-install diagnostic checks with traffic-light output.
# Called by install.sh after the config phase.
# Intentionally non-fatal: each check is independent so one missing tool
# does not mask others.
#
# Environment:
#   VERBOSE - set to 1 for extra debug lines (not currently used here,
#             but accepted for consistency with installer context)

# Traffic-light output gives an easy visual summary of final state.
printf '🚦 Post-install checks\n'

if command -v brew >/dev/null 2>&1; then
  printf '🟢 brew: %s\n' "$(brew --version | awk 'NR==1{print $0}')"
else
  printf '🔴 brew: not found\n'
fi

if command -v starship >/dev/null 2>&1; then
  printf '🟢 starship: %s\n' "$(starship --version 2>/dev/null || echo 'available')"
else
  printf '🔴 starship: not found\n'
fi

if command -v pyenv >/dev/null 2>&1; then
  printf '🟢 pyenv: %s\n' "$(pyenv --version 2>/dev/null || echo 'available')"
else
  printf '🟡 pyenv: not found (optional)\n'
fi

if command -v python3 >/dev/null 2>&1; then
  printf '🟢 python3: %s %s\n' "$(command -v python3)" "$(python3 --version 2>/dev/null || true)"
else
  printf '🔴 python3: not found\n'
fi

if command -v nano >/dev/null 2>&1; then
  printf '🟢 nano: %s\n' "$(nano --version 2>/dev/null | awk 'NR==1{print $0}')"
else
  printf '🟡 nano: not found (optional)\n'
fi

if command -v tmux >/dev/null 2>&1; then
  printf '🟢 tmux: %s\n' "$(tmux -V 2>/dev/null || echo 'available')"
else
  printf '🟡 tmux: not found (optional)\n'
fi
