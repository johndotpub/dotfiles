#!/usr/bin/env bash
set -euo pipefail

# Validate that repeated installer runs accumulate distinct backup files when
# user files are modified between runs, and that a fully idempotent run (files
# already match skel) creates no additional backups.
#
# Coverage: .zshrc, .gitconfig, .zshenv
# Rounds: 4 (2 mutations, 1 idempotent, 1 more mutation) → 3 backup files each.
#   3 runs → 2 .bak files; 4 runs → 3 .bak files.
#
# This test uses distinct frozen timestamps per run so backup filenames are
# deterministic and non-colliding.  Collision-suffix behaviour (same timestamp,
# multiple runs) is covered by test/backup-collision.sh.

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

# ── Round 1 ───────────────────────────────────────────────────────────────────
# Seed user-managed files that differ from skel; each must be backed up.

cat > "${HOME_DIR}/.zshrc" <<'EOF'
# user zshrc round 1 — differs from skel
export ROUND=1
EOF

cat > "${HOME_DIR}/.gitconfig" <<'EOF'
[core]
  editor = vim
EOF

cat > "${HOME_DIR}/.zshenv" <<'EOF'
# user zshenv round 1 — differs from skel
export ZSHENV_ROUND=1
EOF

run_install "20990201000001"

# Round 1: each file must have exactly one .bak.TS backup with the round-1 timestamp.
test -f "${HOME_DIR}/.zshrc.bak.20990201000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000001"
test -f "${HOME_DIR}/.zshenv.bak.20990201000001"

# Verify original content is preserved in the backups.
if ! grep -q "ROUND=1" "${HOME_DIR}/.zshrc.bak.20990201000001"; then
  echo "FAIL: round-1 .zshrc backup does not contain original content." >&2; exit 1
fi
if ! grep -q "editor = vim" "${HOME_DIR}/.gitconfig.bak.20990201000001"; then
  echo "FAIL: round-1 .gitconfig backup does not contain original content." >&2; exit 1
fi
if ! grep -q "ZSHENV_ROUND=1" "${HOME_DIR}/.zshenv.bak.20990201000001"; then
  echo "FAIL: round-1 .zshenv backup does not contain original content." >&2; exit 1
fi

# ── Round 2 ───────────────────────────────────────────────────────────────────
# Simulate user edits to the deployed skel files between runs.
# A second install with a new timestamp must create fresh backups without
# touching or overwriting the round-1 backups.

printf '%s\n' '# user edit after round 1' >> "${HOME_DIR}/.zshrc"
printf '%s\n' '[alias]' >> "${HOME_DIR}/.gitconfig"
printf '%s\n' '  lg = log --oneline' >> "${HOME_DIR}/.gitconfig"
printf '%s\n' '# user edit after round 1' >> "${HOME_DIR}/.zshenv"

run_install "20990201000002"

# Both round-1 and round-2 backups must coexist.
test -f "${HOME_DIR}/.zshrc.bak.20990201000001"
test -f "${HOME_DIR}/.zshrc.bak.20990201000002"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000002"
test -f "${HOME_DIR}/.zshenv.bak.20990201000001"
test -f "${HOME_DIR}/.zshenv.bak.20990201000002"

# Round-1 backups must be intact (not overwritten).
if ! grep -q "ROUND=1" "${HOME_DIR}/.zshrc.bak.20990201000001"; then
  echo "FAIL: round-1 .zshrc backup was overwritten by round 2." >&2; exit 1
fi

# ── Round 3 — idempotent ──────────────────────────────────────────────────────
# All deployed files now match skel exactly (round 2 just re-deployed skel copies).
# A third install must detect the match and create no new backup files.

zshrc_baks_before=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_baks_before=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_baks_before=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

run_install "20990201000003"

zshrc_baks_after=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_baks_after=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_baks_after=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

if [[ "$zshrc_baks_after" -gt "$zshrc_baks_before" ]]; then
  echo "FAIL: unexpected new .zshrc backup on idempotent round 3." >&2; exit 1
fi
if [[ "$gitconfig_baks_after" -gt "$gitconfig_baks_before" ]]; then
  echo "FAIL: unexpected new .gitconfig backup on idempotent round 3." >&2; exit 1
fi
if [[ "$zshenv_baks_after" -gt "$zshenv_baks_before" ]]; then
  echo "FAIL: unexpected new .zshenv backup on idempotent round 3." >&2; exit 1
fi

# ── Round 4 ───────────────────────────────────────────────────────────────────
# Mutate the deployed files again; a fourth run must create a third set of
# backups — confirming: 3 runs → 2 .bak files, 4 runs → 3 .bak files.

printf '%s\n' '# user edit after round 3' >> "${HOME_DIR}/.zshrc"
printf '%s\n' '# user edit after round 3' >> "${HOME_DIR}/.gitconfig"
printf '%s\n' '# user edit after round 3' >> "${HOME_DIR}/.zshenv"

run_install "20990201000004"

# Round-4 backups must exist.
test -f "${HOME_DIR}/.zshrc.bak.20990201000004"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000004"
test -f "${HOME_DIR}/.zshenv.bak.20990201000004"

# All earlier backups must still be intact.
test -f "${HOME_DIR}/.zshrc.bak.20990201000001"
test -f "${HOME_DIR}/.zshrc.bak.20990201000002"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000002"
test -f "${HOME_DIR}/.zshenv.bak.20990201000001"
test -f "${HOME_DIR}/.zshenv.bak.20990201000002"

# Exact backup counts: each file must have exactly 3 .bak.* files.
zshrc_final=$(compgen -G "${HOME_DIR}/.zshrc.bak.*" | wc -l)
gitconfig_final=$(compgen -G "${HOME_DIR}/.gitconfig.bak.*" | wc -l)
zshenv_final=$(compgen -G "${HOME_DIR}/.zshenv.bak.*" | wc -l)

if [[ "$zshrc_final" -ne 3 ]]; then
  echo "FAIL: expected 3 .zshrc backups after round 4, got ${zshrc_final}." >&2; exit 1
fi
if [[ "$gitconfig_final" -ne 3 ]]; then
  echo "FAIL: expected 3 .gitconfig backups after round 4, got ${gitconfig_final}." >&2; exit 1
fi
if [[ "$zshenv_final" -ne 3 ]]; then
  echo "FAIL: expected 3 .zshenv backups after round 4, got ${zshenv_final}." >&2; exit 1
fi

echo "Backup accumulation checks passed (4-round, 3-backup coverage)."
