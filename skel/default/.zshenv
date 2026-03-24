# ~/.zshenv
# Minimal environment setup for all zsh modes.

# Export DOCKER_HOST only if Podman socket exists
[[ -S /run/user/1000/podman/podman.sock ]] && export DOCKER_HOST=unix:///run/user/1000/podman/podman.sock

# Local user paths
export PATH="$HOME/.local/bin:$PATH"

# pyenv environment
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"

# npm and node environment
export PATH="$HOME/.npm-global/bin:$PATH"
export NODE_OPTIONS="--dns-result-order=ipv4first"

### CUDA — generic environment module ###
# Only run if /usr/local/cuda exists and is a directory or symlink
if [ -d /usr/local/cuda ]; then
    # Prepend CUDA bin if not already present
    case ":$PATH:" in
        *":/usr/local/cuda/bin:"*) ;;
        *) export PATH="/usr/local/cuda/bin:$PATH" ;;
    esac

    # Prepend CUDA lib64 if not already present
    if [ -d /usr/local/cuda/lib64 ]; then
        case ":${LD_LIBRARY_PATH:-}:" in
            *":/usr/local/cuda/lib64:"*) ;;
            *) export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}" ;;
        esac
    fi
fi

# Homebrew environment (Linuxbrew)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# OpenClaw environment — delegate to shared init snippet.
[[ -f "${HOME}/.config/openclaw.sh" ]] && source "${HOME}/.config/openclaw.sh"
