#!/usr/bin/env bash

# Shared helper used by setup scripts.
# Loads Homebrew environment into current shell when brew exists in PATH.
setup_brew_env() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
  fi
}
