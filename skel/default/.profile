# Basic profile for login shells
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export LANG="en_US.UTF-8"

# Homebrew environment (Linux + macOS)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
fi
