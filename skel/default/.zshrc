# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Path setup
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

ZSH_THEME="robbyrussell"

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

HIST_STAMPS="yyyy-mm-dd"
HISTSIZE=-1
HISTFILESIZE=-1
HISTCONTROL=ignoreboth

plugins=(git pyenv python pip tmux)
# Useful default plugins that align with installed tooling/flows.
if [[ -d "$ZSH/plugins/fzf" ]]; then
  plugins+=(fzf)
fi
if [[ -d "$ZSH/plugins/sudo" ]]; then
  plugins+=(sudo)
fi
if [[ -d "$ZSH" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

export LANG="en_US.UTF-8"

# STARSHIP
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
