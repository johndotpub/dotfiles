# ~/.zshenv
# Minimal environment setup for all zsh modes.

# Local user paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.npm-global/bin:$PATH"

# Homebrew environment (Linuxbrew)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Export DOCKER_HOST only if Podman socket exists
[[ -S /run/user/1000/podman/podman.sock ]] && export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock

# pyenv environment
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"

# OpenClaw environment — delegate to shared init snippet.
[[ -f "${HOME}/.config/openclaw.sh" ]] && source "${HOME}/.config/openclaw.sh"
