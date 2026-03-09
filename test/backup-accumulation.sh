#!/usr/bin/env bash
set -euo pipefail

# Validate that repeated installer runs accumulate distinct backup files when
# user files are modified between runs, and that a fully idempotent run (files
# already match skel) creates no additional backups.
#
# Coverage: .zshrc, .gitconfig, .zshenv
#
# This test uses distinct frozen timestamps per run so backup filenames are
# deterministic and non-colliding.  Collision-suffix behaviour (same timestamp,
# multiple runs) is covered by test/backup-collision.sh.
#
# Acceptance guard:
# - After 3 total installer runs (run, mutate+run, idempotent run), each tracked
#   file must have exactly 2 backups.
# - After a 4th total installer run following another user edit, each tracked
#   file must have exactly 3 backups.

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

# Track the files whose backup counts this accumulation test asserts.
TRACKED_FILES=(
  ".zshrc"
  ".gitconfig"
  ".zshenv"
)

# Convenience wrapper: run install.sh with a frozen timestamp and common flags.
run_install() {
  local ts="$1"; shift
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:$PATH" SHELL="/bin/zsh" \
    DOTFILES_TEST_TIMESTAMP="$ts" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes "$@" --ref accum-test >/dev/null
}

# Count backups for one tracked file without failing when there are no matches.
count_backups() {
  local relative_path="$1"
  local matches=()
  shopt -s nullglob
  matches=( "${HOME_DIR}/${relative_path}.bak."* )
  shopt -u nullglob
  printf '%s\n' "${#matches[@]}"
}

# Assert an exact backup count so repeated rerun expectations stay explicit.
assert_backup_count() {
  local relative_path="$1"
  local expected_count="$2"
  local context="$3"
  local actual_count
  actual_count="$(count_backups "$relative_path")"
  if [[ "$actual_count" -ne "$expected_count" ]]; then
    echo "FAIL: expected ${expected_count} backups for ${relative_path} ${context}, found ${actual_count}." >&2
    exit 1
  fi
}

# Assert the current backup count for every tracked file.
assert_all_backup_counts() {
  local expected_count="$1"
  local context="$2"
  local relative_path=""
  for relative_path in "${TRACKED_FILES[@]}"; do
    assert_backup_count "$relative_path" "$expected_count" "$context"
  done
}

# Verify one timestamped backup still contains the expected preserved content.
assert_backup_contains() {
  local relative_path="$1"
  local timestamp="$2"
  local needle="$3"
  if ! grep -q "$needle" "${HOME_DIR}/${relative_path}.bak.${timestamp}"; then
    echo "FAIL: ${relative_path}.bak.${timestamp} does not contain expected preserved content: ${needle}" >&2
    exit 1
  fi
}

# Simulate user edits between runs so default backup-and-replace runs keep rotating.
mutate_deployed_files() {
  local marker="$1"
  printf '%s\n' "# ${marker}" >> "${HOME_DIR}/.zshrc"
  printf '%s\n' "[alias]" >> "${HOME_DIR}/.gitconfig"
  printf '%s\n' "  ${marker// /-} = log --oneline" >> "${HOME_DIR}/.gitconfig"
  printf '%s\n' "# ${marker}" >> "${HOME_DIR}/.zshenv"
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
assert_all_backup_counts 1 "after round 1"

# Verify original content is preserved in the backups.
assert_backup_contains ".zshrc" "20990201000001" "ROUND=1"
assert_backup_contains ".gitconfig" "20990201000001" "editor = vim"
assert_backup_contains ".zshenv" "20990201000001" "ZSHENV_ROUND=1"

# ── Round 2 ───────────────────────────────────────────────────────────────────
# Simulate user edits to the deployed skel files between runs.
# A second install with a new timestamp must create fresh backups without
# touching or overwriting the round-1 backups.

mutate_deployed_files "user edit after round 1"

run_install "20990201000002"

# Both round-1 and round-2 backups must coexist.
test -f "${HOME_DIR}/.zshrc.bak.20990201000001"
test -f "${HOME_DIR}/.zshrc.bak.20990201000002"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000001"
test -f "${HOME_DIR}/.gitconfig.bak.20990201000002"
test -f "${HOME_DIR}/.zshenv.bak.20990201000001"
test -f "${HOME_DIR}/.zshenv.bak.20990201000002"
assert_all_backup_counts 2 "after round 2"

# Round-1 backups must be intact (not overwritten).
assert_backup_contains ".zshrc" "20990201000001" "ROUND=1"
assert_backup_contains ".zshrc" "20990201000002" "user edit after round 1"
assert_backup_contains ".gitconfig" "20990201000002" "user-edit-after-round-1 = log --oneline"
assert_backup_contains ".zshenv" "20990201000002" "user edit after round 1"

# ── Round 3 — idempotent ──────────────────────────────────────────────────────
# All deployed files now match skel exactly (round 2 just re-deployed skel copies).
# A third install must detect the match and create no new backup files.  This
# is the explicit "3 total runs -> 2 backups" acceptance case.

run_install "20990201000003"
assert_all_backup_counts 2 "after round 3"

# ── Round 4 — another user edit before rerun ──────────────────────────────────
# A fresh mutation before the fourth total installer run must rotate one more
# timestamped backup for every tracked file.  This is the explicit
# "4 total runs -> 3 backups" acceptance case.

mutate_deployed_files "user edit after round 3"

run_install "20990201000004"
assert_all_backup_counts 3 "after round 4"
assert_backup_contains ".zshrc" "20990201000004" "user edit after round 3"
assert_backup_contains ".gitconfig" "20990201000004" "user-edit-after-round-3 = log --oneline"
assert_backup_contains ".zshenv" "20990201000004" "user edit after round 3"

echo "Backup accumulation checks passed."
