#!/usr/bin/env bash
set -euo pipefail

# Validate inference install policy:
# 1) No inference scripts run unless --install-inference is explicitly set.
# 2) With --install-inference, both upstream installer URLs are invoked.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
MARKER="${TMP_DIR}/inference-runs.log"
ORIG_PATH="$PATH"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Curl shim writes a runnable temp installer script that logs invocation URL.
cat > "${FAKE_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      out="$2"
      shift 2
      ;;
    -*)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
[[ -n "$out" ]] || exit 1
cat > "$out" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '${url}' >> '${INFERENCE_MARKER:?}'
SCRIPT
chmod +x "$out"
EOF
chmod +x "${FAKE_BIN}/curl"

run_install() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" INFERENCE_MARKER="$MARKER" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag inference-test "$@" >/dev/null
}

run_install_no_yes() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" INFERENCE_MARKER="$MARKER" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --tag inference-test "$@" >/dev/null
}

# Default path: no inference scripts should run.
run_install
if [[ -f "$MARKER" ]] && [[ -s "$MARKER" ]]; then
  echo "Inference installer scripts ran without --install-inference." >&2
  exit 1
fi

# Opt-in path: both inference installer scripts should run once.
run_install --install-inference
if [[ ! -f "$MARKER" ]]; then
  echo "Inference marker file missing after --install-inference run." >&2
  exit 1
fi

line_count="$(wc -l < "$MARKER" | tr -d '[:space:]')"
if [[ "$line_count" -ne 2 ]]; then
  echo "Expected exactly 2 inference installer invocations, got ${line_count}." >&2
  exit 1
fi

grep -Fq "https://ollama.ai/install.sh" "$MARKER"
grep -Fq "https://llmfit.axjns.dev/install.sh" "$MARKER"

# Non-interactive + --install-inference without -y should skip remote scripts.
before_count="$line_count"
run_install_no_yes --install-inference
after_count="$(wc -l < "$MARKER" | tr -d '[:space:]')"
if [[ "$before_count" -ne "$after_count" ]]; then
  echo "Inference installers should be skipped in non-interactive mode without --yes." >&2
  exit 1
fi

echo "Inference opt-in behavior checks passed."
