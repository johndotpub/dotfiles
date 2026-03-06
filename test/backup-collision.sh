#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Use isolated HOME/PATH and fake toolchain for deterministic tests.
HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

# Shared shims cover brew/starship/pyenv/git/make behavior.
setup_common_fake_bin "$FAKE_BIN"

# Seed files that will be overridden twice.
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
# Freeze timestamp so backup collision suffixing is testable.
export DOTFILES_TEST_TIMESTAMP="20990101010101"

# Two override runs with identical timestamp must suffix backup names.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --override --tag backup-test >/dev/null
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --override --tag backup-test >/dev/null

test -f "${HOME_DIR}/.zshrc.bak.20990101010101"
test -f "${HOME_DIR}/.zshrc.bak.20990101010101.1"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101.1"

echo "Backup collision handling checks passed."
