#!/usr/bin/env bash
set -euo pipefail

# Verify the installer warms sudo once up front for manual brew-only runs and
# then reuses cached sudo for later privileged shell-setup steps.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(make_tmp_dir)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"
setup_common_fake_bin "$FAKE_BIN"

sudo_log="${TMP_DIR}/sudo.log"
sudo_state_dir="${TMP_DIR}/sudo-state"
etc_shells_capture="${TMP_DIR}/etc-shells"
chsh_log="${TMP_DIR}/chsh.log"

cat > "${FAKE_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SUDO_SHIM_LOG_FILE}"
mkdir -p "${SUDO_SHIM_STATE_DIR}"
case "${1:-}" in
  -v)
    : > "${SUDO_SHIM_STATE_DIR}/warmed"
    exit 0
    ;;
  -n)
    if [[ ! -f "${SUDO_SHIM_STATE_DIR}/warmed" ]]; then
      exit 1
    fi
    shift
    exec "$@"
    ;;
  *)
    echo "Test shim error: Unexpected interactive sudo call: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/sudo"

cat > "${FAKE_BIN}/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/zsh"

cat > "${FAKE_BIN}/tee" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-a" && "${2:-}" == "/etc/shells" ]]; then
  cat >> "${ETC_SHELLS_CAPTURE}"
  exit 0
fi
exec /usr/bin/tee "$@"
EOF
chmod +x "${FAKE_BIN}/tee"

cat > "${FAKE_BIN}/chsh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CHSH_LOG_FILE}"
exit 0
EOF
chmod +x "${FAKE_BIN}/chsh"

output="$(
  HOME="${HOME_DIR}" \
  PATH="${FAKE_BIN}:/usr/bin:/bin" \
  SHELL="/bin/bash" \
  SUDO_SHIM_LOG_FILE="${sudo_log}" \
  SUDO_SHIM_STATE_DIR="${sudo_state_dir}" \
  ETC_SHELLS_CAPTURE="${etc_shells_capture}" \
  CHSH_LOG_FILE="${chsh_log}" \
  "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref sudo-single-prompt-test 2>&1
)"

if [[ "$(grep -xc -- '-v' "${sudo_log}")" -ne 1 ]]; then
  echo "Expected exactly one upfront sudo warmup for the manual install flow." >&2
  exit 1
fi

if ! grep -Eq -- '^-n tee -a /etc/shells$' "${sudo_log}"; then
  echo "Expected cached sudo to register the zsh path in /etc/shells." >&2
  exit 1
fi

if ! grep -Eq -- '^-n chsh -s .+zsh .+$' "${sudo_log}"; then
  echo "Expected cached sudo to be reused for chsh so no second password is needed." >&2
  exit 1
fi

if ! grep -Fq "${FAKE_BIN}/zsh" "${etc_shells_capture}"; then
  echo "Expected the zsh path to be appended to /etc/shells via cached sudo." >&2
  exit 1
fi

if ! grep -Fq "Registered ${FAKE_BIN}/zsh in /etc/shells." <<<"${output}"; then
  echo "Expected installer output to confirm /etc/shells registration." >&2
  exit 1
fi

if ! grep -Fq -- "-s ${FAKE_BIN}/zsh" "${chsh_log}"; then
  echo "Expected chsh to be invoked with the resolved zsh path." >&2
  exit 1
fi

echo "Single-prompt sudo flow checks passed."
