#!/usr/bin/env bash
set -euo pipefail

# Validate SSH config include migration behavior:
# 1) Existing ~/.ssh/config with no config.local is migrated to config.local and
#    managed include wrapper is created at ~/.ssh/config.
# 2) Existing ~/.ssh/config with existing config.local is preserved by default.
# 3) Existing config.local without config gets managed include wrapper copied in.

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
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag ssh-migrate "$@" >/dev/null
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

# Scenario 2: preserve existing config when config.local already exists.
HOME_TWO="${TMP_DIR}/home-two"
mkdir -p "${HOME_TWO}/.ssh"
cat > "${HOME_TWO}/.ssh/config" <<'EOF'
Host keep-config
  HostName keep.example
EOF
cat > "${HOME_TWO}/.ssh/config.local" <<'EOF'
Host keep-local
  HostName keep-local.example
EOF

run_install_for_home "$HOME_TWO"

grep -Fq "Host keep-config" "${HOME_TWO}/.ssh/config"
grep -Fq "Host keep-local" "${HOME_TWO}/.ssh/config.local"

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

echo "SSH include migration checks passed."
