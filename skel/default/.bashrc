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

brew_env_initialized=0
brew_env_output=""

if command -v brew >/dev/null 2>&1; then
  if brew_env_output="$(brew shellenv 2>/dev/null)"; then
    if eval "$brew_env_output"; then
      brew_env_initialized=1
    fi
  fi
fi

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

# Prefer zsh for interactive terminals unless the user opts out.
if [[ $- == *i* ]] && [[ -z "${ZSH_VERSION:-}" ]] && [[ -z "${DOTFILES_KEEP_BASH:-}" ]]; then
  if command -v zsh >/dev/null 2>&1; then
    exec zsh -l
  fi
fi

# STARSHIP
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi
