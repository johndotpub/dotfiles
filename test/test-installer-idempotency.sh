#!/usr/bin/env bash
set -euo pipefail

# Integration test goals:
#  1) Default run preserves existing user config files.
#  2) Re-running stays idempotent (no surprise backup files).
#  3) --override creates .bak.<timestamp> backups before replacement.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Isolate HOME/PATH so tests never touch real user config.
HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

# Shim external tools for deterministic, offline test behavior.
cat > "${FAKE_BIN}/brew" <<'EOF'
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
chmod +x "${FAKE_BIN}/brew"

# Starship shim supports the exact preset command used by installer.
cat > "${FAKE_BIN}/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
  echo "starship 1.0.0-test"
  exit 0
fi
if [[ "${1:-}" == "preset" && "${2:-}" == "tokyo-night" && "${3:-}" == "-o" ]]; then
  target="${4:-}"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' '# tokyo-night preset test config' > "$target"
  exit 0
fi
if [[ "${1:-}" == "preset" && "${2:-}" == "--help" ]]; then
  echo "starship preset help"
  exit 0
fi
echo "starship 1.0.0-test"
EOF
chmod +x "${FAKE_BIN}/starship"

# pyenv shim keeps version probes predictable.
cat > "${FAKE_BIN}/pyenv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  versions)
    exit 0
    ;;
  --version)
    echo "pyenv 2.4.0-test"
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/pyenv"

# git/make shims support nanorc clone + install path.
cat > "${FAKE_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  target="${@: -1}"
  mkdir -p "$target"
  cat > "${target}/Makefile" <<'OUT'
install:
	@echo "nanorc install"
OUT
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/git"

cat > "${FAKE_BIN}/make" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/make"

# Seed user-managed files that should be preserved by default.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# existing zshrc should be preserved
export KEEP_ME=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"

# First run: should preserve existing files and add missing config.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag ci-test >/dev/null

grep -q "KEEP_ME=1" "${HOME_DIR}/.zshrc"
grep -q "editor = vim" "${HOME_DIR}/.gitconfig"
test -f "${HOME_DIR}/.config/starship.toml"

# Second run: should remain idempotent without creating backups.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag ci-test >/dev/null

grep -q "KEEP_ME=1" "${HOME_DIR}/.zshrc"
grep -q "editor = vim" "${HOME_DIR}/.gitconfig"

if compgen -G "${HOME_DIR}/.zshrc.bak.*" >/dev/null; then
  echo "Unexpected .zshrc backups found on rerun."
  exit 1
fi

if compgen -G "${HOME_DIR}/.gitconfig.bak.*" >/dev/null; then
  echo "Unexpected .gitconfig backups found on rerun."
  exit 1
fi

# Override run: must create backups before replacing existing files.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --override --tag ci-test >/dev/null

if ! compgen -G "${HOME_DIR}/.zshrc.bak.*" >/dev/null; then
  echo "Expected .zshrc backup not found with --override."
  exit 1
fi

if ! compgen -G "${HOME_DIR}/.gitconfig.bak.*" >/dev/null; then
  echo "Expected .gitconfig backup not found with --override."
  exit 1
fi

echo "Installer idempotency checks passed."
