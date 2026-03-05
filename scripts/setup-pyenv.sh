#!/usr/bin/env bash
set -euo pipefail

# Locate this script so sourcing helper works regardless of caller cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/brew-env.sh
source "${SCRIPT_DIR}/lib/brew-env.sh"

# Load brew env before invoking brew subcommands.
setup_brew_env

# Keep this script intentionally small: install tooling only.
# Shell initialization is handled by skel/default/.zshrc.
brew install pyenv pyenv-virtualenv || true

if [[ -d "${HOME}/.oh-my-zsh" ]]; then
  zsh_custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
  plugin_dir="${zsh_custom}/plugins/zsh-pyenv"
  mkdir -p "${zsh_custom}/plugins"
  if [[ ! -d "$plugin_dir" ]]; then
    git clone --depth 1 https://github.com/mattberther/zsh-pyenv.git "$plugin_dir" || true
  fi
fi
