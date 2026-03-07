#!/usr/bin/env bash
set -euo pipefail

# Integration test goals:
#  1) Default run backs up existing user config files and deploys fresh skel copies.
#  2) Re-running is idempotent when deployed files already match skel (no new backups).
#  3) --preserve keeps existing files unchanged with no backups created.

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

# Seed user-managed files that exist before the installer runs.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# existing zshrc — should be backed up and replaced by default
export KEEP_ME=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"

# First run: default behaviour backs up existing files and deploys fresh copies.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref ci-test >/dev/null

# After first run, .zshrc must have been backed up (moved to .bak.*).
if ! compgen -G "${HOME_DIR}/.zshrc.bak.*" >/dev/null; then
  echo "Expected .zshrc backup not found on first run (default backup-and-replace)."
  exit 1
fi

# The fresh skel .zshrc must exist and must NOT contain the old marker.
if ! test -f "${HOME_DIR}/.zshrc"; then
  echo "Expected skel .zshrc to be deployed on first run."
  exit 1
fi
if grep -q "KEEP_ME=1" "${HOME_DIR}/.zshrc"; then
  echo "Expected .zshrc to be replaced (original content should be in backup only)."
  exit 1
fi

# .gitconfig must also have been backed up.
if ! compgen -G "${HOME_DIR}/.gitconfig.bak.*" >/dev/null; then
  echo "Expected .gitconfig backup not found on first run."
  exit 1
fi

# The starship config must have been deployed.
test -f "${HOME_DIR}/.config/starship.toml"

# Second run: deployed files now match skel — no new backups should appear.
zshrc_bak_count_before="$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)"
gitconfig_bak_count_before="$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)"

"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref ci-test >/dev/null

zshrc_bak_count_after="$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)"
gitconfig_bak_count_after="$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)"

if [[ "$zshrc_bak_count_after" -gt "$zshrc_bak_count_before" ]]; then
  echo "Unexpected new .zshrc backups found on idempotent rerun."
  exit 1
fi
if [[ "$gitconfig_bak_count_after" -gt "$gitconfig_bak_count_before" ]]; then
  echo "Unexpected new .gitconfig backups found on idempotent rerun."
  exit 1
fi

# --preserve run: existing files must be kept unchanged; no backups created.
HOME_PRESERVE="${TMP_DIR}/home-preserve"
mkdir -p "$HOME_PRESERVE"
cat > "${HOME_PRESERVE}/.zshrc" <<'EOF'
# keep-this-zshrc
export PRESERVE_ME=1
EOF

HOME="$HOME_PRESERVE" PATH="${FAKE_BIN}:$PATH" SHELL="/bin/zsh" \
  "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --preserve --ref ci-test >/dev/null

# Content must be unchanged.
if ! grep -q "PRESERVE_ME=1" "${HOME_PRESERVE}/.zshrc"; then
  echo "Expected .zshrc to be preserved unchanged with --preserve."
  exit 1
fi

# No backup files should exist.
if compgen -G "${HOME_PRESERVE}/.zshrc.bak.*" >/dev/null; then
  echo "Unexpected .zshrc backup found with --preserve."
  exit 1
fi

echo "Installer idempotency checks passed."
