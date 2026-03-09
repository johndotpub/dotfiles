#!/usr/bin/env bash
set -euo pipefail

# Validate split package inventory behavior:
# 1) packages/brew.yaml is sufficient on its own; packages/packages.yaml is no longer required.
# 2) Brew installs every section by default when no inventory override is present.
# 3) Apt installs no optional sections by default, but inventory can opt into specific sections.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(make_tmp_dir)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
PKG_DIR="${TMP_DIR}/packages"
DEFAULT_INVENTORY_DIR="${TMP_DIR}/inventory-default"
SECTIONED_INVENTORY_DIR="${TMP_DIR}/inventory-sectioned"
BREW_MARKER="${TMP_DIR}/brew.log"
APT_MARKER="${TMP_DIR}/apt.log"
ORIG_PATH="$PATH"

mkdir -p "$HOME_DIR" "$FAKE_BIN" "$PKG_DIR" "$DEFAULT_INVENTORY_DIR" "$SECTIONED_INVENTORY_DIR"
setup_common_fake_bin "$FAKE_BIN"
write_sudo_shim "$FAKE_BIN"

# Brew shim logs every install invocation so the test can assert section selection.
cat > "${FAKE_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
case "$cmd" in
  shellenv)
    cat <<'OUT'
export HOMEBREW_PREFIX=/tmp/fakebrew
export HOMEBREW_CELLAR=/tmp/fakebrew/Cellar
export HOMEBREW_REPOSITORY=/tmp/fakebrew/Homebrew
export PATH=/tmp/fakebrew/bin:$PATH
OUT
    ;;
  install)
    shift
    printf '%s\n' "$*" >> "${BREW_MARKER:?}"
    ;;
  --version)
    echo "Homebrew 4.4.0"
    ;;
esac
exit 0
EOF
chmod +x "${FAKE_BIN}/brew"

# Apt shim captures both baseline and optional installs; assertions focus on the
# uniquely named optional packages so baseline behavior remains unaffected.
cat > "${FAKE_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${APT_MARKER:?}"
exit 0
EOF
chmod +x "${FAKE_BIN}/apt-get"

# Locale helpers are touched by the Linux apt path; shimming them keeps the
# test focused on package section selection instead of host locale permissions.
for cmd in locale-gen update-locale; do
  cat > "${FAKE_BIN}/${cmd}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${FAKE_BIN}/${cmd}"
done

cat > "${PKG_DIR}/brew.yaml" <<'EOF'
base:
  - brew-base
development:
  - brew-dev
inference:
  - ollama
  - llmfit
EOF

cat > "${PKG_DIR}/apt.yaml" <<'EOF'
apt_minimal:
  - apt-optional-one
extras:
  - apt-optional-two
EOF

cat > "${DEFAULT_INVENTORY_DIR}/default.yaml" <<'EOF'
profile: dev
create_home_pyver: false
pyver: "3.12.12"
skel_profile: "default"
EOF

cat > "${SECTIONED_INVENTORY_DIR}/default.yaml" <<'EOF'
profile: dev
create_home_pyver: false
pyver: "3.12.12"
skel_profile: "default"
brew_sections:
  - base
apt_sections:
  - apt_minimal
EOF

run_install() {
  local inventory_dir="$1"
  shift
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" \
    BREW_MARKER="$BREW_MARKER" APT_MARKER="$APT_MARKER" \
    "${REPO_DIR}/install.sh" \
    --yes \
    --ref package-sections-test \
    --packages-dir "$PKG_DIR" \
    --inventory-dir "$inventory_dir" \
    "$@" >/dev/null
}

# Scenario 1: brew installs every section by default and does not require the legacy packages.yaml file.
run_install "$DEFAULT_INVENTORY_DIR" --no-apt
if [[ ! -s "$BREW_MARKER" ]]; then
  echo "Expected brew install log to be written for default package flow." >&2
  exit 1
fi
grep -Fq "brew-base brew-dev ollama llmfit" "$BREW_MARKER"
if [[ -e "${PKG_DIR}/packages.yaml" ]]; then
  echo "Legacy packages.yaml should not be required for the split package inventory test." >&2
  exit 1
fi
if [[ -e "$APT_MARKER" ]]; then
  echo "Apt should not run when --no-apt is supplied." >&2
  exit 1
fi

# Scenario 2: inventory overrides can narrow brew sections and opt into apt sections.
: > "$BREW_MARKER"
: > "$APT_MARKER"
run_install "$SECTIONED_INVENTORY_DIR"
grep -Fq "brew-base" "$BREW_MARKER"
if grep -Fq "brew-dev" "$BREW_MARKER"; then
  echo "Brew section override should exclude brew-dev." >&2
  exit 1
fi
if grep -Fq "llmfit" "$BREW_MARKER"; then
  echo "Brew section override should exclude inference packages when not selected." >&2
  exit 1
fi
grep -Fq "apt-optional-one" "$APT_MARKER"
if grep -Fq "apt-optional-two" "$APT_MARKER"; then
  echo "Apt section override should exclude apt-optional-two." >&2
  exit 1
fi

echo "Split package section behavior checks passed."
