#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TAG="${1:-v0.0.0-test}"
REPO_NAME="$(basename "$REPO_DIR")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_a="${tmp_dir}/${REPO_NAME}-${TAG}.a.tar.gz"
archive_b="${tmp_dir}/${REPO_NAME}-${TAG}.b.tar.gz"

create_archive() {
  local out_file="$1"
  tar \
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

sum_a="$(sha256sum "$archive_a" | awk '{print $1}')"
sum_b="$(sha256sum "$archive_b" | awk '{print $1}')"

if [[ "$sum_a" != "$sum_b" ]]; then
  echo "Release tarball reproducibility check failed." >&2
  echo "first=${sum_a}" >&2
  echo "second=${sum_b}" >&2
  exit 1
fi

echo "Reproducibility check passed (${sum_a})."
