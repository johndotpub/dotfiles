#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

cat > "${FAKE_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  shellenv)
    cat <<'OUT'
export PATH=/tmp/fakebrew/bin:$PATH
OUT
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

cat > "${FAKE_BIN}/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
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
chmod +x "${FAKE_BIN}/starship"

cat > "${FAKE_BIN}/pyenv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "versions" ]]; then
  exit 0
fi
echo "pyenv 2.4.0-test"
EOF
chmod +x "${FAKE_BIN}/pyenv"

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
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/git"

cat > "${FAKE_BIN}/make" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/make"

cat > "${HOME_DIR}/.zshrc" <<'EOF'
# original
export ORIGINAL_ZSHRC=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"
export DOTFILES_TEST_TIMESTAMP="20990101010101"

"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --override --tag backup-test >/dev/null
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --override --tag backup-test >/dev/null

test -f "${HOME_DIR}/.zshrc.bak.20990101010101"
test -f "${HOME_DIR}/.zshrc.bak.20990101010101.1"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101.1"

echo "Backup collision handling checks passed."
