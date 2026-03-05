#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TAG="${1:-v0.0.0-test}"
REPO_NAME="$(basename "$REPO_DIR")"

# Prefer gtar when installed (common on macOS via Homebrew).
tar_bin="tar"
if command -v gtar >/dev/null 2>&1; then
  tar_bin="gtar"
fi

if ! "$tar_bin" --version 2>/dev/null | awk 'NR==1 {print $0}' | awk '/GNU tar/{found=1} END{exit(found?0:1)}'; then
  echo "GNU tar is required for deterministic archive verification." >&2
  echo "Install gnu-tar (macOS: brew install gnu-tar) and retry." >&2
  exit 1
fi

# Portable SHA256 helper for Linux/macOS environments.
sha256_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return 0
  fi
  echo "No SHA256 tool found (need sha256sum or shasum)." >&2
  return 1
}

# Compare two independent archive builds to catch non-determinism.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_a="${tmp_dir}/${REPO_NAME}-${TAG}.a.tar.gz"
archive_b="${tmp_dir}/${REPO_NAME}-${TAG}.b.tar.gz"

create_archive() {
  local out_file="$1"
  # Normalized metadata makes tar output reproducible across runs.
  "$tar_bin" \
    --sort=name \
    --mtime='UTC 1970-01-01' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --exclude='.git' \
    --exclude='./dist' \
    -czf "$out_file" \
    -C "$REPO_DIR" .
}

create_archive "$archive_a"
create_archive "$archive_b"

# Hash comparison is the final reproducibility assertion.
sum_a="$(sha256_cmd "$archive_a")"
sum_b="$(sha256_cmd "$archive_b")"

if [[ "$sum_a" != "$sum_b" ]]; then
  echo "Release tarball reproducibility check failed." >&2
  echo "first=${sum_a}" >&2
  echo "second=${sum_b}" >&2
  exit 1
fi

echo "Reproducibility check passed (${sum_a})."
