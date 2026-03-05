#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

MANIFEST_FILE="${REPO_DIR}/packages/manifest.json"
BREW_OUT="${REPO_DIR}/packages/brew-packages.txt"
APT_OUT="${REPO_DIR}/packages/apt-minimal.txt"

MODE="write"
if [[ "${1:-}" == "--check" ]]; then
  MODE="check"
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: scripts/generate-package-manifests.sh [--check]

Reads packages/manifest.json and writes:
  - packages/brew-packages.txt
  - packages/apt-minimal.txt

Use --check to verify generated files are up to date.
EOF
  exit 0
fi

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Missing manifest file: ${MANIFEST_FILE}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

tmp_brew="${tmp_dir}/brew-packages.txt"
tmp_apt="${tmp_dir}/apt-minimal.txt"

python3 - "$MANIFEST_FILE" "$tmp_brew" "$tmp_apt" <<'PY'
import json
import sys

manifest_path, brew_out, apt_out = sys.argv[1:4]

with open(manifest_path, "r", encoding="utf-8") as f:
    data = json.load(f)

def write_list(key, out_path):
    value = data.get(key)
    if not isinstance(value, list):
        raise SystemExit(f"manifest key '{key}' must be a list")
    cleaned = []
    for item in value:
        if not isinstance(item, str):
            raise SystemExit(f"manifest key '{key}' contains non-string item")
        item = item.strip()
        if not item:
            raise SystemExit(f"manifest key '{key}' contains empty item")
        cleaned.append(item)
    with open(out_path, "w", encoding="utf-8") as out:
        for item in cleaned:
            out.write(f"{item}\n")

write_list("brew", brew_out)
write_list("apt_minimal", apt_out)
PY

if [[ "$MODE" == "check" ]]; then
  if ! cmp -s "$tmp_brew" "$BREW_OUT"; then
    echo "packages/brew-packages.txt is out of date. Run scripts/generate-package-manifests.sh" >&2
    exit 1
  fi
  if ! cmp -s "$tmp_apt" "$APT_OUT"; then
    echo "packages/apt-minimal.txt is out of date. Run scripts/generate-package-manifests.sh" >&2
    exit 1
  fi
  echo "Package manifests are up to date."
  exit 0
fi

cp "$tmp_brew" "$BREW_OUT"
cp "$tmp_apt" "$APT_OUT"
echo "Updated package manifests from packages/manifest.json."
