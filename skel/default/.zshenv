# ~/.zshenv
# Minimal environment setup for all zsh modes.

# Local user paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Homebrew environment (Linuxbrew)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# pyenv environment
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"

# OpenClaw environment — delegate to shared init snippet.
[[ -f "${HOME}/.config/openclaw.sh" ]] && source "${HOME}/.config/openclaw.sh"
