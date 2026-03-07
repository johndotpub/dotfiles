#!/usr/bin/env bash
set -euo pipefail

# Validate SSH config include migration behavior:
# 1) Existing ~/.ssh/config with no config.local is migrated to config.local and
#    managed include wrapper is created at ~/.ssh/config.
# 2) Existing ~/.ssh/config with existing config.local: config.local is backed up,
#    config content is migrated (sanitized) to a new config.local.
# 3) Existing config.local without config gets managed include wrapper copied in.
# 4) Self-referencing Include lines are sanitized from migrated config.local content.
# 5) Rerun is idempotent (managed include wrapper already present guard).
# 6) Config consisting only of self-include/comment lines leaves no config.local.

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
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref ssh-migrate "$@" >/dev/null
}

# Scenario 1: migrate config -> config.local and seed include wrapper.
HOME_ONE="${TMP_DIR}/home-one"
mkdir -p "${HOME_ONE}/.ssh"
cat > "${HOME_ONE}/.ssh/config" <<'EOF'
Host oldhost
  HostName old.example
EOF

run_install_for_home "$HOME_ONE"

grep -Fq "Host oldhost" "${HOME_ONE}/.ssh/config.local"
grep -Fq "Include ~/.ssh/config.local" "${HOME_ONE}/.ssh/config"

# Scenario 2: config.local already exists -> it is backed up and config is migrated.
HOME_TWO="${TMP_DIR}/home-two"
mkdir -p "${HOME_TWO}/.ssh"
cat > "${HOME_TWO}/.ssh/config" <<'EOF'
Host migrate-config
  HostName migrate.example
EOF
cat > "${HOME_TWO}/.ssh/config.local" <<'EOF'
Host original-local
  HostName original-local.example
EOF

export DOTFILES_TEST_TIMESTAMP="20990101010101"
run_install_for_home "$HOME_TWO"
unset DOTFILES_TEST_TIMESTAMP

# Migrated content should appear in config.local.
grep -Fq "Host migrate-config" "${HOME_TWO}/.ssh/config.local"
# Original config.local should be backed up.
if ! compgen -G "${HOME_TWO}/.ssh/config.local.bak.*" >/dev/null; then
  echo "Expected backup of existing config.local not found."
  exit 1
fi
# Managed include wrapper must be seeded.
grep -Fq "Include ~/.ssh/config.local" "${HOME_TWO}/.ssh/config"

# Scenario 3: config.local exists and config missing -> include wrapper copied in.
HOME_THREE="${TMP_DIR}/home-three"
mkdir -p "${HOME_THREE}/.ssh"
cat > "${HOME_THREE}/.ssh/config.local" <<'EOF'
Host local-only
  HostName local-only.example
EOF

run_install_for_home "$HOME_THREE"

grep -Fq "Include ~/.ssh/config.local" "${HOME_THREE}/.ssh/config"
grep -Fq "Host local-only" "${HOME_THREE}/.ssh/config.local"

# Scenario 4: Self-referencing include lines are sanitized from migrated content.
HOME_FOUR="${TMP_DIR}/home-four"
mkdir -p "${HOME_FOUR}/.ssh"
cat > "${HOME_FOUR}/.ssh/config" <<'EOF'
# Load user-specific hosts/overrides from local-only file.
Include ~/.ssh/config.local

Host realhost
  HostName real.example
EOF

run_install_for_home "$HOME_FOUR"

# Managed include wrapper must be seeded.
grep -Fq "Include ~/.ssh/config.local" "${HOME_FOUR}/.ssh/config"
# realhost content must be migrated.
grep -Fq "Host realhost" "${HOME_FOUR}/.ssh/config.local"
# Self-include line must NOT appear in the migrated config.local.
if grep -qF 'Include ~/.ssh/config.local' "${HOME_FOUR}/.ssh/config.local"; then
  echo "Self-referencing Include line found in migrated config.local."
  exit 1
fi
if grep -qF '# Load user-specific hosts/overrides from local-only file.' "${HOME_FOUR}/.ssh/config.local"; then
  echo "Self-referencing comment line found in migrated config.local."
  exit 1
fi

# Scenario 5: Rerun is idempotent (managed wrapper already present -> no re-migration).
HOME_FIVE="${TMP_DIR}/home-five"
mkdir -p "${HOME_FIVE}/.ssh"
# Simulate a post-migration state: config has the include wrapper.
cat > "${HOME_FIVE}/.ssh/config" <<'EOF'
# Load user-specific hosts/overrides from local-only file.
Include ~/.ssh/config.local

Host *
  AddKeysToAgent yes
EOF
cat > "${HOME_FIVE}/.ssh/config.local" <<'EOF'
Host myhost
  HostName my.example
EOF

run_install_for_home "$HOME_FIVE"

# No backup of config.local should be created on rerun.
if compgen -G "${HOME_FIVE}/.ssh/config.local.bak.*" >/dev/null; then
  echo "Unexpected backup of config.local created on rerun."
  exit 1
fi
# config.local should be unchanged.
grep -Fq "Host myhost" "${HOME_FIVE}/.ssh/config.local"

# Scenario 6: config contains ONLY the self-referencing include/comment lines;
# after sanitization the result is empty — installer must not abort and must not
# create an empty config.local (regression guard for set -eo pipefail + grep -v).
HOME_SIX="${TMP_DIR}/home-six"
mkdir -p "${HOME_SIX}/.ssh"
cat > "${HOME_SIX}/.ssh/config" <<'EOF'
# Load user-specific hosts/overrides from local-only file.
Include ~/.ssh/config.local
EOF

run_install_for_home "$HOME_SIX"

# config.local must NOT be created when there is nothing meaningful to migrate.
if [[ -f "${HOME_SIX}/.ssh/config.local" ]]; then
  echo "Empty config.local was unexpectedly created for whitespace-only migrated content."
  exit 1
fi
# The managed include wrapper should still be seeded at ~/.ssh/config.
grep -Fq "Include ~/.ssh/config.local" "${HOME_SIX}/.ssh/config"

# Scenario 7: --preserve leaves both ~/.ssh/config and ~/.ssh/config.local untouched.
# Neither file should be modified, backed up, or overwritten.
HOME_SEVEN="${TMP_DIR}/home-seven"
mkdir -p "${HOME_SEVEN}/.ssh"
cat > "${HOME_SEVEN}/.ssh/config" <<'EOF'
Host mypreservedhost
  HostName preserved.example
EOF
cat > "${HOME_SEVEN}/.ssh/config.local" <<'EOF'
Host preserved-local
  HostName preserved-local.example
EOF

run_install_for_home "$HOME_SEVEN" --preserve

# Both files must be unchanged — preserve mode skips SSH migration entirely.
grep -Fq "Host mypreservedhost" "${HOME_SEVEN}/.ssh/config"
grep -Fq "Host preserved-local" "${HOME_SEVEN}/.ssh/config.local"

# No backup of config.local should have been created.
if compgen -G "${HOME_SEVEN}/.ssh/config.local.bak.*" >/dev/null; then
  echo "Unexpected backup of config.local created under --preserve."
  exit 1
fi

# The managed include wrapper must NOT have been injected into config.
if grep -qF 'Include ~/.ssh/config.local' "${HOME_SEVEN}/.ssh/config"; then
  echo "Include wrapper was injected into ~/.ssh/config under --preserve."
  exit 1
fi

echo "SSH include migration checks passed."
