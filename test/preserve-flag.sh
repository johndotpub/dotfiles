#!/usr/bin/env bash
set -euo pipefail

# Validate --preserve flag behavior:
#  1) Existing files are kept unchanged — no backups, no replacement.
#  2) Missing files are still copied from skel (normal fresh-install path).
#  3) No .bak.* files are created anywhere when --preserve is set.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Seed user-managed files that must remain unchanged.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# user-managed zshrc — must NOT be touched by --preserve
export KEEP_ME_PRESERVE=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = nano
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"
# Freeze timestamp so any accidental backup would be easy to detect.
export DOTFILES_TEST_TIMESTAMP="20990101010101"

"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --preserve --ref preserve-test >/dev/null

# Existing .zshrc must be unchanged.
if ! grep -q "KEEP_ME_PRESERVE=1" "${HOME_DIR}/.zshrc"; then
  echo "FAIL: .zshrc was modified with --preserve (must be kept as-is)" >&2
  exit 1
fi

# Existing .gitconfig must be unchanged.
if ! grep -q "editor = nano" "${HOME_DIR}/.gitconfig"; then
  echo "FAIL: .gitconfig was modified with --preserve (must be kept as-is)" >&2
  exit 1
fi

# No .bak.* files of any kind must exist.
if compgen -G "${HOME_DIR}/*.bak.*" >/dev/null 2>&1; then
  echo "FAIL: unexpected .bak.* files found with --preserve:" >&2
  compgen -G "${HOME_DIR}/*.bak.*" >&2
  exit 1
fi
if compgen -G "${HOME_DIR}/.*.bak.*" >/dev/null 2>&1; then
  echo "FAIL: unexpected .*.bak.* files found with --preserve:" >&2
  compgen -G "${HOME_DIR}/.*.bak.*" >&2
  exit 1
fi

# Missing files (e.g. .config/starship.toml) must still be deployed.
if [[ ! -f "${HOME_DIR}/.config/starship.toml" ]]; then
  echo "FAIL: missing skel file not deployed with --preserve" >&2
  exit 1
fi

echo "--preserve flag checks passed."
