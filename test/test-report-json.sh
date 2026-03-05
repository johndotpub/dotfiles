#!/usr/bin/env bash
set -euo pipefail

# Validate that --report-json writes syntactically valid JSON and
# includes expected top-level fields/phase keys.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
REPORT_PATH="${TMP_DIR}/report.json"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"

# Include control characters in tag to verify escaping robustness.
TAG_WITH_CONTROLS=$'ci\tline\nbreak\rcarriage'
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag "$TAG_WITH_CONTROLS" --report-json "$REPORT_PATH" >/dev/null

if [[ ! -f "$REPORT_PATH" ]]; then
  echo "Expected report file was not written: ${REPORT_PATH}" >&2
  exit 1
fi

python3 - "$REPORT_PATH" "$TAG_WITH_CONTROLS" <<'PY'
import json
import sys

path = sys.argv[1]
expected_tag = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

required_top = ["status", "exit_code", "tag", "host", "from_release", "dry_run", "override", "phase"]
for key in required_top:
    if key not in data:
        raise SystemExit(f"missing top-level key: {key}")

if data["status"] != "success":
    raise SystemExit(f"unexpected status: {data['status']}")
if data["exit_code"] != 0:
    raise SystemExit(f"unexpected exit_code: {data['exit_code']}")
if data["tag"] != expected_tag:
    raise SystemExit("tag field did not round-trip through JSON escaping")

phase = data.get("phase", {})
for key in ["lock", "preflight", "apt_baseline", "brew_bootstrap", "brew_packages", "apt_fallback", "inference", "config", "checks"]:
    if key not in phase:
        raise SystemExit(f"missing phase key: {key}")
PY

echo "Report JSON validation checks passed."
