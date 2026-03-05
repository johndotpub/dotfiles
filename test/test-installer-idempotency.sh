#!/usr/bin/env bash
set -euo pipefail

# Integration test goals:
#  1) Default run preserves existing user config files.
#  2) Re-running stays idempotent (no surprise backup files).
#  3) --override creates .bak.<timestamp> backups before replacement.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Isolate HOME/PATH so tests never touch real user config.
HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

# Shared shims cover brew/starship/pyenv/git/make behavior.
setup_common_fake_bin "$FAKE_BIN"

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
