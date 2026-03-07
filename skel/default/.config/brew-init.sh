#!/usr/bin/env bash

# Homebrew environment initialisation — sourced by .zshrc and .bashrc.
# Handles the chicken-and-egg PATH problem for Linuxbrew: brew is not on PATH
# until shellenv is evaluated, so we probe a list of candidate locations first.
#
# This block is intentionally idempotent: skip if already initialized.

# Build candidate list; prepend HOMEBREW_PREFIX-based path when the variable
# is already exported (e.g. via a parent process or earlier shell init).
brew_candidates=(
  /home/linuxbrew/.linuxbrew/bin/brew
  "$HOME/.linuxbrew/bin/brew"
  /opt/homebrew/bin/brew
  /usr/local/bin/brew
)
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  brew_candidates=("${HOMEBREW_PREFIX}/bin/brew" "${brew_candidates[@]}")
fi

brew_env_initialized=0
brew_env_output=""

# Try PATH brew first (fastest path; already on PATH from a prior shell init).
if command -v brew >/dev/null 2>&1; then
  if brew_env_output="$(brew shellenv 2>/dev/null)"; then
    if eval "$brew_env_output"; then
      brew_env_initialized=1
    fi
  fi
fi

# Fall back to probing known install locations.
if [[ "$brew_env_initialized" -eq 0 ]]; then
  for brew_bin in "${brew_candidates[@]}"; do
    if [[ -x "$brew_bin" ]]; then
      if brew_env_output="$("$brew_bin" shellenv 2>/dev/null)"; then
        if eval "$brew_env_output"; then
          brew_env_initialized=1
          break
        fi
      fi
    fi
  done
fi
unset brew_bin brew_candidates brew_env_output brew_env_initialized
