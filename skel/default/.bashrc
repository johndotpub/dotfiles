#!/usr/bin/env bash

# Path setup
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Homebrew environment
brew_candidates=(
  /home/linuxbrew/.linuxbrew/bin/brew
  "$HOME/.linuxbrew/bin/brew"
  /opt/homebrew/bin/brew
  /usr/local/bin/brew
)
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  brew_candidates=("${HOMEBREW_PREFIX}/bin/brew" "${brew_candidates[@]}")
fi

if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  for brew_bin in "${brew_candidates[@]}"; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
fi
unset brew_bin brew_candidates

# STARSHIP
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
