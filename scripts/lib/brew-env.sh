#!/usr/bin/env bash

# Shared helper used by setup scripts.
# Loads Homebrew environment into current shell when brew exists in PATH.
# Search order prefers current PATH first, then standard macOS brew prefixes.
setup_brew_env() {
  local brew_bin=""

  if command -v brew >/dev/null 2>&1; then
    brew_bin="$(command -v brew)"
  elif [ -x /opt/homebrew/bin/brew ]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [ -x /usr/local/bin/brew ]; then
    brew_bin="/usr/local/bin/brew"
  fi

  if [ -n "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
  fi
}
