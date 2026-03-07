#!/usr/bin/env bash
set -euo pipefail

# Validate both backup primitives used by install.sh:
#
#   backup_path (rename/move):
#     - Used by: skel deploy, starship, tmux, SSH, python-version
#     - Semantics: original is MOVED to .bak.<ts>; original path is gone
#
#   backup_copy (copy-then-keep):
#     - Used by: nanorc default mode
#     - Semantics: original is COPIED to .bak.<ts>; original path is preserved
#
# Both paths are exercised by seeding the relevant files before running
# install.sh in its default (backup-and-replace) mode with a frozen timestamp.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(make_tmp_dir)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Provide no-op shims for privileged/system commands.
write_sudo_shim "$FAKE_BIN"
for cmd in apt-get locale-gen update-locale chsh; do
  cat > "${FAKE_BIN}/${cmd}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${FAKE_BIN}/${cmd}"
done

# Seed .zshrc to trigger backup_path (skel deploy, default mode).
# backup_path MOVES the file: original must be gone after, .bak.TS must exist.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# original zshrc — must be moved (not kept) in default backup-and-replace mode
export ORIGINAL_ZSHRC=1
EOF

# Seed .nanorc WITHOUT the include line to trigger backup_copy (nanorc, default mode).
# backup_copy COPIES the file: original must still exist after, .bak.TS must also exist.
cat > "${HOME_DIR}/.nanorc" <<'EOF'
# custom nano settings
set tabsize 4
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:/usr/bin:/bin"
export SHELL="/bin/zsh"
# Freeze timestamp so backup names are deterministic.
export DOTFILES_TEST_TIMESTAMP="20990303030303"

# Default mode (no flags): backup-and-replace.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag backup-sem-test >/dev/null

# ── backup_path semantics ─────────────────────────────────────────────────────
# .zshrc must have been backed up (moved) — the backup file must exist.
if [[ ! -f "${HOME_DIR}/.zshrc.bak.20990303030303" ]]; then
  echo "FAIL: backup_path did not create .zshrc.bak.20990303030303" >&2
  exit 1
fi

# The original content must be in the backup (not lost).
if ! grep -q "ORIGINAL_ZSHRC=1" "${HOME_DIR}/.zshrc.bak.20990303030303"; then
  echo "FAIL: .zshrc.bak.20990303030303 does not contain original content" >&2
  exit 1
fi

# The fresh .zshrc deployed by the installer must exist (skel replaced it).
if [[ ! -f "${HOME_DIR}/.zshrc" ]]; then
  echo "FAIL: install.sh did not deploy a replacement .zshrc after default backup-and-replace" >&2
  exit 1
fi

# The new .zshrc must NOT contain the original marker (it's from skel, not the original).
if grep -q "ORIGINAL_ZSHRC=1" "${HOME_DIR}/.zshrc"; then
  echo "FAIL: .zshrc still contains original content after backup_path backup-and-replace" >&2
  exit 1
fi

echo "backup_path semantics OK: original moved to .bak.TS, skel version deployed."

# ── backup_copy semantics ─────────────────────────────────────────────────────
# .nanorc must have been backed up (copied) — the backup file must exist.
if [[ ! -f "${HOME_DIR}/.nanorc.bak.20990303030303" ]]; then
  echo "FAIL: backup_copy did not create .nanorc.bak.20990303030303" >&2
  exit 1
fi

# The backup must contain the original content.
if ! grep -q "custom nano settings" "${HOME_DIR}/.nanorc.bak.20990303030303"; then
  echo "FAIL: .nanorc.bak.20990303030303 does not contain original content" >&2
  exit 1
fi

# The ORIGINAL .nanorc must still be present (backup_copy keeps it).
if [[ ! -f "${HOME_DIR}/.nanorc" ]]; then
  echo "FAIL: backup_copy removed the original .nanorc (should keep it in place)" >&2
  exit 1
fi

# The original content must still be present in .nanorc (it was appended to, not replaced).
if ! grep -q "custom nano settings" "${HOME_DIR}/.nanorc"; then
  echo "FAIL: .nanorc lost original content after backup_copy backup-and-replace" >&2
  exit 1
fi

# The include line must have been appended to .nanorc.
if ! grep -Fxq "include ~/.nano/*.nanorc" "${HOME_DIR}/.nanorc"; then
  echo "FAIL: nanorc include line was not appended to .nanorc after default backup-and-replace" >&2
  exit 1
fi

echo "backup_copy semantics OK: original kept in place, .bak.TS copy created, include appended."

echo "Backup semantics checks passed."
