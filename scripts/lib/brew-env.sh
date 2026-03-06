#!/usr/bin/env bash

# Shared helper used by setup scripts.
# Loads Homebrew environment into current shell when brew exists.
# Search order prefers current PATH, then explicit prefix, then common defaults.
setup_brew_env() {
  local brew_bin=""
  local candidate=""

  if command -v brew >/dev/null 2>&1; then
    brew_bin="$(command -v brew)"
  elif [ -n "${HOMEBREW_PREFIX:-}" ] && [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then
    brew_bin="${HOMEBREW_PREFIX}/bin/brew"
  else
    for candidate in \
      /home/linuxbrew/.linuxbrew/bin/brew \
      "${HOME}/.linuxbrew/bin/brew" \
      /opt/homebrew/bin/brew \
      /usr/local/bin/brew
    do
      if [ -x "$candidate" ]; then
        brew_bin="$candidate"
        break
      fi
    done
  fi

  if [ -n "$brew_bin" ] && [ -x "$brew_bin" ]; then
    eval "$("$brew_bin" shellenv)"
    return 0
  fi
  return 1
}
