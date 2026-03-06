#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-bootstrap-e2e 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap-e2e.XXXXXX"
}

tmp_dir="$(mktemp_dir)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

asset_dir="${tmp_dir}/assets"
fake_bin="${tmp_dir}/bin"
home_dir="${tmp_dir}/home"
mkdir -p "$asset_dir" "$fake_bin" "$home_dir"

setup_common_fake_bin "$fake_bin"

tag="v0.0.0-pr-e2e"
# bootstrap.sh resolves artifact names from its REPO constant (dotfiles).
asset_basename="dotfiles-${tag}.tar.gz"

# Build a local release-like payload from the active working tree so bootstrap
# installs the current PR commit content (not a previously published release).
tar -czf "${asset_dir}/${asset_basename}" \
  --exclude='.git' \
  --exclude='./dist' \
  -C "$REPO_DIR" .

sha256_file="${asset_dir}/${asset_basename}.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "${asset_dir}/${asset_basename}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  checksum="$(shasum -a 256 "${asset_dir}/${asset_basename}" | awk '{print $1}')"
else
  echo "No SHA256 tool found (need sha256sum or shasum)." >&2
  exit 1
fi
printf '%s  %s\n' "$checksum" "$asset_basename" > "$sha256_file"

cp "${REPO_DIR}/bootstrap.sh" "${asset_dir}/bootstrap.sh"

# Use curl exactly as end users do; BOOTSTRAP_RELEASE_BASE points downloads at
# the local payload so CI can validate PR commits end-to-end.
curl -fsSL "file://${asset_dir}/bootstrap.sh" | \
  BOOTSTRAP_RELEASE_BASE="file://${asset_dir}" \
  HOME="$home_dir" \
  PATH="${fake_bin}:/usr/bin:/bin" \
  SHELL="/bin/zsh" \
  bash -s -- --tag "$tag" --no-apt --brew-only --yes >/dev/null

if [[ ! -f "${home_dir}/.zshrc" ]]; then
  echo "E2E bootstrap test did not deploy ~/.zshrc from PR payload." >&2
  exit 1
fi

echo "Bootstrap curl E2E PR payload test passed."
