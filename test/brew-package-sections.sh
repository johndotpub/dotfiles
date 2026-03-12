#!/usr/bin/env bash
set -euo pipefail

# Validate brew.yaml section install policy:
# 1) All sections of packages/brew.yaml are installed on a normal run.
# 2) The apt_minimal section is NOT installed when --brew-only is set.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
BREW_LOG="${TMP_DIR}/brew-install.log"
APT_LOG="${TMP_DIR}/apt-install.log"
ORIG_PATH="$PATH"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Override the brew shim to log all packages passed to "brew install".
cat > "${FAKE_BIN}/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cmd="\${1:-}"
case "\$cmd" in
  shellenv)
    cat <<'OUT'
export HOMEBREW_PREFIX=/tmp/fakebrew
export HOMEBREW_CELLAR=/tmp/fakebrew/Cellar
export HOMEBREW_REPOSITORY=/tmp/fakebrew/Homebrew
export PATH=/tmp/fakebrew/bin:\$PATH
OUT
    ;;
  install)
    shift
    # Log each package argument on its own line for easy assertion.
    for pkg in "\$@"; do printf '%s\n' "\$pkg"; done >> "${BREW_LOG}"
    exit 0
    ;;
  --version)
    echo "Homebrew 4.4.0"
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/brew"

# Override the apt-get shim to log packages that would be installed.
cat > "${FAKE_BIN}/apt-get" <<EOF
#!/usr/bin/env bash
# Log packages from: apt-get install -y <pkgs...>
if [[ "\${1:-}" == "install" ]]; then
  shift
  for arg in "\$@"; do
    [[ "\$arg" == -* ]] && continue
    printf '%s\n' "\$arg" >> "${APT_LOG}"
  done
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/apt-get"

run_install() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" \
    "${REPO_DIR}/install.sh" --yes --ref brew-test "$@" >/dev/null
}

# ── Assertion 1: all brew.yaml sections are installed on a normal (--brew-only) run ──
# Read expected packages from every section in brew.yaml.
BREW_YAML="${REPO_DIR}/packages/brew.yaml"
expected_brew=()
while IFS= read -r line; do
  expected_brew+=("$line")
done < <(
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^[a-zA-Z0-9_]+:[[:space:]]*$/ { in_section = 1; next }
    in_section && /^[[:space:]]*-[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "$BREW_YAML"
)

run_install --no-apt --brew-only

if [[ ! -f "$BREW_LOG" ]]; then
  echo "FAIL: brew install was never called during a normal run." >&2
  exit 1
fi

for pkg in "${expected_brew[@]}"; do
  if ! grep -Fxq "$pkg" "$BREW_LOG"; then
    echo "FAIL: expected brew package '${pkg}' was not installed." >&2
    exit 1
  fi
done

# ── Assertion 2: apt_minimal packages are NOT installed when --brew-only is set ──
APT_YAML="${REPO_DIR}/packages/apt.yaml"
apt_pkgs=()
while IFS= read -r line; do
  apt_pkgs+=("$line")
done < <(
  awk -v section="apt_minimal" '
    BEGIN { in_section = 0 }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" { in_section = 1; next }
    in_section && $0 ~ "^[[:space:]]*[a-zA-Z0-9_]+:[[:space:]]*$" { in_section = 0 }
    in_section && $0 ~ "^[[:space:]]*-[[:space:]]+" {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "$APT_YAML"
)

if [[ -f "$APT_LOG" ]]; then
  for pkg in "${apt_pkgs[@]}"; do
    if grep -Fxq "$pkg" "$APT_LOG"; then
      echo "FAIL: apt package '${pkg}' should not be installed when --brew-only is set." >&2
      exit 1
    fi
  done
fi

echo "Brew package sections checks passed."
