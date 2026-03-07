#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

tmp_dir="$(make_tmp_dir)"
cleanup() {
  if [[ -n "${server_pid:-}" ]]; then
    kill "${server_pid}" >/dev/null 2>&1 || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

web_root="${tmp_dir}/webroot"
fake_bin="${tmp_dir}/bin"
home_dir="${tmp_dir}/home"
mkdir -p "$web_root" "$fake_bin" "$home_dir"

setup_common_fake_bin "$fake_bin"

# Keep apt/sudo operations fully sandboxed in CI while still exercising the
# default installer flow (README invocation uses only --ref).
write_sudo_shim "$fake_bin"

cat > "${fake_bin}/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${fake_bin}/apt-get"

cat > "${fake_bin}/locale-gen" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin}/locale-gen"

cat > "${fake_bin}/update-locale" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin}/update-locale"

cat > "${fake_bin}/chsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin}/chsh"

tag="v0.0.0-pr-e2e"
# bootstrap.sh resolves artifact names from its REPO constant (dotfiles).
asset_basename="dotfiles-${tag}.tar.gz"
release_dir="${web_root}/releases/download/${tag}"
mkdir -p "$release_dir"

# Build a local release-like payload from the active working tree so bootstrap
# installs the current PR commit content (not a previously published release).
tar -czf "${release_dir}/${asset_basename}" \
  --exclude='.git' \
  --exclude='./dist' \
  -C "$REPO_DIR" .

sha256_file="${release_dir}/${asset_basename}.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "${release_dir}/${asset_basename}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  checksum="$(shasum -a 256 "${release_dir}/${asset_basename}" | awk '{print $1}')"
else
  echo "No SHA256 tool found (need sha256sum or shasum)." >&2
  exit 1
fi
printf '%s  %s\n' "$checksum" "$asset_basename" > "$sha256_file"

cp "${REPO_DIR}/bootstrap.sh" "${web_root}/bootstrap.sh"

# Serve bootstrap and local release assets over HTTP and run the same curl|bash
# shape recommended in README (only `--ref` argument).
start_http_server "$web_root"

curl -fsSL "http://127.0.0.1:${port}/bootstrap.sh" | \
  BOOTSTRAP_RELEASE_BASE="http://127.0.0.1:${port}/releases/download/${tag}" \
  BOOTSTRAP_ARCHIVE_BASE="http://127.0.0.1:${port}/archive" \
  HOME="$home_dir" \
  PATH="${fake_bin}:/usr/bin:/bin" \
  SHELL="/bin/zsh" \
  bash -s -- --ref "$tag" >/dev/null

if [[ ! -f "${home_dir}/.zshrc" ]]; then
  echo "E2E README curl bootstrap test did not deploy ~/.zshrc." >&2
  exit 1
fi

echo "Bootstrap README curl E2E test passed."
