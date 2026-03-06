#!/usr/bin/env bash
set -euo pipefail

# Validate bootstrap.sh main-branch fallback behavior:
# When --tag is omitted, bootstrap.sh should:
#   1) Download the archive pointed to by BOOTSTRAP_MAIN_URL (test override).
#   2) Skip checksum/GPG verification (no .sha256 file for branch archives).
#   3) Extract and run install.sh from the archive.
#   4) Emit an unverified-install warning before proceeding.

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

# Provide no-op shims for privileged/system commands used in the installer.
write_sudo_shim "$fake_bin"
for cmd in apt-get locale-gen update-locale chsh; do
  cat > "${fake_bin}/${cmd}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${fake_bin}/${cmd}"
done

# Build a local archive of the working tree that simulates what GitHub
# serves at /archive/refs/heads/main.tar.gz.
# GitHub names the top-level directory "<repo>-main/" so strip-components=1 works.
# Use a staging directory to create the "dotfiles-main/" top-level prefix instead
# of --transform, which is GNU tar-only and fails on macOS's bsdtar.
asset_basename="dotfiles-main.tar.gz"
staging_root="${tmp_dir}/staging"
mkdir -p "$web_root" "${staging_root}/dotfiles-main"
cp -R "${REPO_DIR}/." "${staging_root}/dotfiles-main/"
rm -rf "${staging_root}/dotfiles-main/.git" "${staging_root}/dotfiles-main/dist"
tar -czf "${web_root}/${asset_basename}" -C "$staging_root" dotfiles-main

# Serve the archive over HTTP so BOOTSTRAP_MAIN_URL can point at it.
port="$(
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
)"

python3 -m http.server "$port" --bind 127.0.0.1 --directory "$web_root" >/dev/null 2>&1 &
server_pid="$!"

# Wait for the server to be ready.
for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${port}/${asset_basename}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# Run the local bootstrap.sh directly (no curl needed for the script itself).
bootstrap_out="$(
  BOOTSTRAP_MAIN_URL="http://127.0.0.1:${port}/${asset_basename}" \
  HOME="$home_dir" \
  PATH="${fake_bin}:/usr/bin:/bin" \
  SHELL="/bin/zsh" \
  bash "${REPO_DIR}/bootstrap.sh" 2>&1
)"

# 1) Unverified-install warning must appear in output.
if ! printf '%s\n' "$bootstrap_out" | grep -q 'No --tag provided'; then
  echo "Expected unverified-install warning not found in bootstrap output." >&2
  echo "$bootstrap_out" >&2
  exit 1
fi

# 2) install.sh must have deployed ~/.zshrc into the isolated home.
if [[ ! -f "${home_dir}/.zshrc" ]]; then
  echo "Bootstrap main-fallback did not deploy ~/.zshrc." >&2
  exit 1
fi

echo "Bootstrap main-branch fallback test passed."
