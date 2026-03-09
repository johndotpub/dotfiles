#!/usr/bin/env bash
set -euo pipefail

# Validate that sudo warmup is skipped when apt work is disabled.
# This keeps --brew-only and --no-apt runs from prompting unnecessarily.

# Locate repository and test directories up front so all shims and install
# invocations resolve against the isolated test workspace.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
SUDO_LOG="${TMP_DIR}/sudo.log"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Create fake sudo that logs invocations so the test can assert that brew-only
# and no-apt runs never warm up or refresh sudo credentials.
cat > "${FAKE_BIN}/sudo" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >> "${SUDO_LOG}"
case "\${1:-}" in
  -v) exit 0 ;;
  -n) shift; exec "\$@" ;;
  *) exec "\$@" ;;
esac
EOF
chmod +x "${FAKE_BIN}/sudo"

run_install() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:$PATH" SHELL="/bin/zsh" \
    "${REPO_DIR}/install.sh" --yes --ref sudo-gating-test "$@" >/dev/null
}

run_install --brew-only
run_install --no-apt

if [[ -f "$SUDO_LOG" ]] && [[ -s "$SUDO_LOG" ]]; then
  echo "Sudo warmup should be skipped for --brew-only and --no-apt runs." >&2
  exit 1
fi

echo "Sudo gating checks passed."
