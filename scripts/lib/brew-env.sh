#!/usr/bin/env bash

# Shared helper used by setup scripts.
# Loads Homebrew environment into current shell when brew exists.
# Search order prefers current PATH, then explicit prefix, then common defaults.
setup_brew_env() {
  local brew_bin=""
  local candidate=""
  local shellenv_output=""

  # `brew` may be a function/alias in interactive shells. If it is callable,
  # prefer that first so we inherit the user's active brew context.
  if command -v brew >/dev/null 2>&1; then
    if shellenv_output="$(brew shellenv)"; then
      if eval "$shellenv_output"; then
        return 0
      fi
    fi
  fi

  # Fall back to explicit binaries for fresh/non-interactive environments.
  if [ -n "${HOMEBREW_PREFIX:-}" ] && [ -x "${HOMEBREW_PREFIX}/bin/brew" ]; then
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
    if shellenv_output="$("$brew_bin" shellenv)"; then
      if eval "$shellenv_output"; then
        return 0
      fi
    fi
  fi
  return 1
}
