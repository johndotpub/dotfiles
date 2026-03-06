#!/usr/bin/env bash

# Shared fake command shims for installer integration tests.
# These keep tests deterministic, offline, and fast.

write_brew_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  shellenv)
    cat <<'OUT'
export HOMEBREW_PREFIX=/tmp/fakebrew
export HOMEBREW_CELLAR=/tmp/fakebrew/Cellar
export HOMEBREW_REPOSITORY=/tmp/fakebrew/Homebrew
export PATH=/tmp/fakebrew/bin:$PATH
OUT
    ;;
  install)
    exit 0
    ;;
  --version)
    echo "Homebrew 4.4.0"
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "${fake_bin}/brew"
}

write_starship_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "starship 1.0.0-test"
  exit 0
fi
if [[ "${1:-}" == "preset" && "${2:-}" == "--help" ]]; then
  echo "starship preset help"
  exit 0
fi
if [[ "${1:-}" == "preset" && "${2:-}" == "tokyo-night" && "${3:-}" == "-o" ]]; then
  target="${4:-}"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' '# tokyo-night preset test config' > "$target"
  exit 0
fi
echo "starship 1.0.0-test"
EOF
  chmod +x "${fake_bin}/starship"
}

write_pyenv_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/pyenv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "versions" ]]; then
  exit 0
fi
echo "pyenv 2.4.0-test"
EOF
  chmod +x "${fake_bin}/pyenv"
}

write_git_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  target="${@: -1}"
  mkdir -p "$target"
  if [[ "$(basename "$target")" == ".tmux" ]]; then
    cat > "${target}/.tmux.conf" <<'OUT'
# fake oh-my-tmux config
OUT
    cat > "${target}/.tmux.conf.local" <<'OUT'
# fake oh-my-tmux local config
OUT
    exit 0
  fi
  cat > "${target}/Makefile" <<'OUT'
install:
	@echo "nanorc install"
OUT
  exit 0
fi
exit 0
EOF
  chmod +x "${fake_bin}/git"
}

write_make_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/make" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${fake_bin}/make"
}

# Install all shared shims into the target fake bin directory.
setup_common_fake_bin() {
  local fake_bin="$1"
  mkdir -p "$fake_bin"
  write_brew_shim "$fake_bin"
  write_starship_shim "$fake_bin"
  write_pyenv_shim "$fake_bin"
  write_git_shim "$fake_bin"
  write_make_shim "$fake_bin"
}

# Portable mktemp wrapper: works on Linux and macOS.
make_tmp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-test 2>/dev/null || \
    mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX"
}

# Sudo shim that handles flag-only invocations used by install.sh.
# sudo -v  → exit 0 (credential warmup, no-op in tests)
# sudo -n  → strip flag and exec remaining args
# sudo <cmd> → exec the command directly
write_sudo_shim() {
  local fake_bin="$1"
  cat > "${fake_bin}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  -v) exit 0 ;;
  -n) shift; exec "$@" ;;
  *) exec "$@" ;;
esac
EOF
  chmod +x "${fake_bin}/sudo"
}
