#!/usr/bin/env bash
set -euo pipefail

# Validate that sudo -v is invoked exactly once per installer run,
# regardless of whether apt mode is enabled.
#
# Reproduces the bug where --no-apt/--brew-only skipped the sudo warmup
# entirely, causing chsh and /etc/shells registration to prompt for a
# password late in the run.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
ORIG_PATH="$PATH"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Add a no-op apt-get shim so the full apt flow doesn't attempt real system calls.
cat > "${FAKE_BIN}/apt-get" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/apt-get"

# Replace the standard sudo shim with a counting variant that logs each
# "-v" invocation so we can assert it happens exactly once per run.
SUDO_V_LOG="${TMP_DIR}/sudo-v.log"
cat > "${FAKE_BIN}/sudo" <<EOF
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-}" in
  -v)
    # Record each credential-warmup call.
    printf 'sudo -v\n' >> "${SUDO_V_LOG}"
    exit 0
    ;;
  -n) shift; exec "\$@" ;;
  *)  exec "\$@" ;;
esac
EOF
chmod +x "${FAKE_BIN}/sudo"

run_install() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" \
    "${REPO_DIR}/install.sh" --yes --ref sudo-test "$@" >/dev/null
}

# ── Test 1: --no-apt --brew-only (previously skipped warmup) ─────────────────
# Reset log.
rm -f "$SUDO_V_LOG"
run_install --no-apt --brew-only

count=0
if [[ -f "$SUDO_V_LOG" ]]; then
  count="$(wc -l < "$SUDO_V_LOG" | tr -d '[:space:]')"
fi

if [[ "$count" -ne 1 ]]; then
  echo "FAIL: expected sudo -v exactly once for --no-apt --brew-only run, got ${count}." >&2
  exit 1
fi

# ── Test 2: full apt flow ─────────────────────────────────────────────────────
rm -f "$SUDO_V_LOG"
run_install

count=0
if [[ -f "$SUDO_V_LOG" ]]; then
  count="$(wc -l < "$SUDO_V_LOG" | tr -d '[:space:]')"
fi

if [[ "$count" -ne 1 ]]; then
  echo "FAIL: expected sudo -v exactly once for full apt run, got ${count}." >&2
  exit 1
fi

echo "sudo single-prompt checks passed."
