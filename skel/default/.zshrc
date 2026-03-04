export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export LANG="en_US.UTF-8"

# Homebrew environment (Linux + macOS)
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Optional Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  export ZSH="$HOME/.oh-my-zsh"
  ZSH_THEME="robbyrussell"
  plugins=(git zsh-pyenv)
  source "$ZSH/oh-my-zsh.sh"
fi

# Starship prompt (initialize last)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
