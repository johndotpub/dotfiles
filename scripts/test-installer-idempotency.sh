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

cat > "${FAKE_BIN}/uv" <<'EOF'
#!/usr/bin/env bash
echo "uv 0.0.0-test"
EOF
chmod +x "${FAKE_BIN}/uv"

cat > "${FAKE_BIN}/starship" <<'EOF'
#!/usr/bin/env bash
echo "starship 1.0.0-test"
EOF
chmod +x "${FAKE_BIN}/starship"

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

"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag ci-test >/dev/null

grep -q "KEEP_ME=1" "${HOME_DIR}/.zshrc"
grep -q "editor = vim" "${HOME_DIR}/.gitconfig"
test -f "${HOME_DIR}/.config/starship.toml"

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

echo "Installer idempotency checks passed."
