#!/usr/bin/env bash

# Path setup
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Homebrew environment — delegate to shared init snippet.
# shellcheck source=.config/brew-init.sh
[[ -f "${HOME}/.config/brew-init.sh" ]] && source "${HOME}/.config/brew-init.sh"

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
