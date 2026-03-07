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

# Seed a file that differs from skel so the first run creates a backup.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# original — first run will back this up
export ORIGINAL_ZSHRC=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

cat > "${HOME_DIR}/.zshenv" <<'EOF'
# original zshenv — collision test
export ZSHENV_ORIG=1
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"
# Freeze timestamp so backup collision suffixing is testable.
export DOTFILES_TEST_TIMESTAMP="20990101010101"

# First run: seeds first backup (.bak.TS).
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref backup-test >/dev/null

# Mutate the deployed files so they differ from skel again — the second run
# must detect the difference and create colliding .bak.TS names, which
# next_backup_path resolves with a numeric suffix (.bak.TS.1).
printf '%s\n' '# mutated between runs' >> "${HOME_DIR}/.zshrc"
printf '%s\n' '[user]' >> "${HOME_DIR}/.gitconfig"
printf '%s\n' '  name = Test' >> "${HOME_DIR}/.gitconfig"
printf '%s\n' '# mutated between runs' >> "${HOME_DIR}/.zshenv"

# Second run with same frozen timestamp must suffix backup names on collision.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref backup-test >/dev/null

test -f "${HOME_DIR}/.zshrc.bak.20990101010101"
test -f "${HOME_DIR}/.zshrc.bak.20990101010101.1"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101"
test -f "${HOME_DIR}/.gitconfig.bak.20990101010101.1"
test -f "${HOME_DIR}/.zshenv.bak.20990101010101"
test -f "${HOME_DIR}/.zshenv.bak.20990101010101.1"

echo "Backup collision handling checks passed."
