# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Path setup
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

ZSH_THEME="robbyrussell"

# Homebrew environment — delegate to shared init snippet.
# shellcheck source=.config/brew-init.sh
[[ -f "${HOME}/.config/brew-init.sh" ]] && source "${HOME}/.config/brew-init.sh"

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
