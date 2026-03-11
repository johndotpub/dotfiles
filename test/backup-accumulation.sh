#!/usr/bin/env bash
set -euo pipefail

# Validate that repeated installer runs accumulate distinct backup files when
# user files are modified between runs, and that a fully idempotent run (files
# already match skel) creates no additional backups.
#
# Strategy: seed a pre-existing backup alongside user-modified files, then run
# the installer twice — one mutating run and one idempotent run. This proves:
#   - Multi-backup accumulation (2 .bak.* files coexist after 1 mutating run)
#   - Content preservation in backups
#   - Idempotent runs create no new backups
#
# Coverage: .zshrc, .gitconfig, .zshenv
#
# Collision-suffix behaviour (same timestamp, multiple runs) is covered by
# test/backup-collision.sh.

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

# Convenience wrapper: run install.sh with a frozen timestamp and common flags.
run_install() {
  local ts="$1"; shift
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:$PATH" SHELL="/bin/zsh" \
    DOTFILES_TEST_TIMESTAMP="$ts" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes "$@" --ref accum-test >/dev/null
}

# ── Seed: pre-existing backups ─────────────────────────────────────────────────
# Simulate a prior run by placing existing .bak.* files so we can confirm that a
# subsequent mutating run adds a new backup alongside them (accumulation proven).
touch "${HOME_DIR}/.zshrc.bak.20990101000001"
touch "${HOME_DIR}/.gitconfig.bak.20990101000001"
touch "${HOME_DIR}/.zshenv.bak.20990101000001"

# ── Seed: user-modified files ──────────────────────────────────────────────────
# These differ from skel so run #1 will back them up before deploying skel.
cat > "${HOME_DIR}/.zshrc" <<'EOF'
# user-modified zshrc — differs from skel
export ROUND=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

cat > "${HOME_DIR}/.zshenv" <<'EOF'
# user-modified zshenv — differs from skel
export ZSHENV_ROUND=1
EOF

# ── Run 1: mutating ────────────────────────────────────────────────────────────
# Modified user files must be backed up; the pre-seeded backups must survive.
run_install "20990201000001"

# New backups must exist with the run-1 timestamp.
test -f "${HOME_DIR}/.zshrc.bak.20990201000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000001"
test -f "${HOME_DIR}/.zshenv.bak.20990201000001"

# Original content must be preserved in the new backups.
if ! grep -q "ROUND=1" "${HOME_DIR}/.zshrc.bak.20990201000001"; then
  echo "FAIL: run-1 .zshrc backup does not contain original content." >&2; exit 1
fi
if ! grep -q "editor = vim" "${HOME_DIR}/.gitconfig.bak.20990201000001"; then
  echo "FAIL: run-1 .gitconfig backup does not contain original content." >&2; exit 1
fi
if ! grep -q "ZSHENV_ROUND=1" "${HOME_DIR}/.zshenv.bak.20990201000001"; then
  echo "FAIL: run-1 .zshenv backup does not contain original content." >&2; exit 1
fi

# The pre-seeded backups must still be present (accumulation: old + new coexist).
test -f "${HOME_DIR}/.zshrc.bak.20990101000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990101000001"
test -f "${HOME_DIR}/.zshenv.bak.20990101000001"

# Each file must now have exactly 2 .bak.* files.
zshrc_count=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_count=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_count=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

if [[ "$zshrc_count" -ne 2 ]]; then
  echo "FAIL: expected 2 .zshrc backups after run 1, got ${zshrc_count}." >&2; exit 1
fi
if [[ "$gitconfig_count" -ne 2 ]]; then
  echo "FAIL: expected 2 .gitconfig backups after run 1, got ${gitconfig_count}." >&2; exit 1
fi
if [[ "$zshenv_count" -ne 2 ]]; then
  echo "FAIL: expected 2 .zshenv backups after run 1, got ${zshenv_count}." >&2; exit 1
fi

# ── Run 2: idempotent ──────────────────────────────────────────────────────────
# Deployed files now match skel exactly — no new backups must be created.
zshrc_baks_before=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_baks_before=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_baks_before=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

run_install "20990201000002"

zshrc_baks_after=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_baks_after=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_baks_after=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

if [[ "$zshrc_baks_after" -gt "$zshrc_baks_before" ]]; then
  echo "FAIL: unexpected new .zshrc backup on idempotent run 2." >&2; exit 1
fi
if [[ "$gitconfig_baks_after" -gt "$gitconfig_baks_before" ]]; then
  echo "FAIL: unexpected new .gitconfig backup on idempotent run 2." >&2; exit 1
fi
if [[ "$zshenv_baks_after" -gt "$zshenv_baks_before" ]]; then
  echo "FAIL: unexpected new .zshenv backup on idempotent run 2." >&2; exit 1
fi

echo "Backup accumulation checks passed (2-run, 2-backup coverage)."
