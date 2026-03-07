#!/usr/bin/env bash
set -euo pipefail

# Validate oh-my-tmux bootstrap behavior:
#  1) Fresh home gets ~/.tmux clone + ~/.tmux.conf symlink + ~/.tmux.conf.local.
#  2) Existing ~/.tmux.conf is backed up and replaced with a symlink by default.
#  3) --preserve keeps existing ~/.tmux.conf unchanged, no backup.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
ORIG_PATH="$PATH"
mkdir -p "$FAKE_BIN"
setup_common_fake_bin "$FAKE_BIN"

run_install_for_home() {
  local home_dir="$1"
  shift
  HOME="$home_dir" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag tmux-test "$@" >/dev/null
}

assert_no_backups() {
  local home_dir="$1"
  if compgen -G "${home_dir}/.tmux.conf.bak.*" >/dev/null; then
    echo "Unexpected ~/.tmux.conf backup files in ${home_dir}" >&2
    exit 1
  fi
}

# Scenario 1: fresh home gets oh-my-tmux bootstrap and local override file.
HOME_ONE="${TMP_DIR}/home-one"
mkdir -p "$HOME_ONE"
run_install_for_home "$HOME_ONE"
test -d "${HOME_ONE}/.tmux"
test -L "${HOME_ONE}/.tmux.conf"
test -f "${HOME_ONE}/.tmux/.tmux.conf"
test -f "${HOME_ONE}/.tmux.conf.local"

# Scenario 2: existing ~/.tmux.conf is backed up and replaced with symlink by default.
HOME_TWO="${TMP_DIR}/home-two"
mkdir -p "$HOME_TWO"
printf '%s\n' '# replace-me-tmux-conf' > "${HOME_TWO}/.tmux.conf"
run_install_for_home "$HOME_TWO"
# The .tmux.conf must now be a symlink (replaced).
test -L "${HOME_TWO}/.tmux.conf"
# A backup of the original must exist.
if ! compgen -G "${HOME_TWO}/.tmux.conf.bak.*" >/dev/null; then
  echo "Expected ~/.tmux.conf backup not found in default backup-and-replace scenario." >&2
  exit 1
fi

# Scenario 3: --preserve keeps existing ~/.tmux.conf unchanged with no backup.
HOME_THREE="${TMP_DIR}/home-three"
mkdir -p "$HOME_THREE"
printf '%s\n' '# keep-my-tmux-conf' > "${HOME_THREE}/.tmux.conf"
run_install_for_home "$HOME_THREE" --preserve
grep -Fxq "# keep-my-tmux-conf" "${HOME_THREE}/.tmux.conf"
assert_no_backups "$HOME_THREE"

echo "oh-my-tmux behavior checks passed."
