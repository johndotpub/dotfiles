#!/usr/bin/env bash
set -euo pipefail

# Validate installer lock behavior by running one install that holds the lock
# and confirming a concurrent second install exits with lock contention.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
HOME_DIR="${TMP_DIR}/home"
ORIG_PATH="$PATH"
LOCK_DIR="/tmp/dotfiles-install.${UID}.lock"
mkdir -p "$FAKE_BIN" "$HOME_DIR"
setup_common_fake_bin "$FAKE_BIN"

# Override brew shim so package install pauses and keeps lock held briefly.
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
    sleep 3
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

rm -rf "$LOCK_DIR"

(
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" XDG_RUNTIME_DIR="" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref lock-test-one >/dev/null 2>"${TMP_DIR}/first.err"
) &
first_pid=$!

# Wait until lock appears (up to ~3 seconds).
for _ in $(seq 1 30); do
  if [[ -d "$LOCK_DIR" ]]; then
    break
  fi
  sleep 0.1
done

if [[ ! -d "$LOCK_DIR" ]]; then
  echo "Installer lock directory was not created in time." >&2
  wait "$first_pid" || true
  exit 1
fi

set +e
HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" XDG_RUNTIME_DIR="" \
  "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref lock-test-two >/dev/null 2>"${TMP_DIR}/second.err"
second_rc=$?
set -e

wait "$first_pid"

if [[ "$second_rc" -eq 0 ]]; then
  echo "Second installer run unexpectedly succeeded under lock contention." >&2
  exit 1
fi

if ! grep -Fq "already running" "${TMP_DIR}/second.err"; then
  echo "Expected lock contention message not found in second run output." >&2
  exit 1
fi

echo "Installer lock behavior checks passed."
