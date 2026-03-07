#!/usr/bin/env bash
set -euo pipefail

# Validate bootstrap.sh branch ref resolution:
# When --ref is a branch name, bootstrap.sh should:
#   1) Detect the branch via a HEAD request to refs/heads/{ref} (200 from local server).
#   2) Download the archive directly (no release asset lookup).
#   3) Skip checksum/GPG verification and emit the skip warning.
#   4) Extract and run install.sh from the archive.
#   5) Deploy config files into the isolated home directory.

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

# Simulate a branch ref named "test-branch".
# bootstrap.sh will probe refs/heads/test-branch via HEAD and, upon getting 200,
# download the archive directly (no release asset, no checksum verification).
branch_ref="test-branch"

# Serve the branch archive at the path bootstrap.sh will request:
#   GET ${BOOTSTRAP_ARCHIVE_BASE}/refs/heads/{ref}.tar.gz
# The URL path uses the bare ref name (e.g. test-branch.tar.gz), matching
# what GitHub serves at /archive/refs/heads/{ref}.tar.gz.
branch_archive_dir="${web_root}/archive/refs/heads"
mkdir -p "$branch_archive_dir"

# Build a local archive of the working tree to serve as the branch archive.
# Use a staging directory to prefix contents with "dotfiles-test-branch/" so
# strip-components=1 works the same as a real GitHub branch archive.
staging_root="${tmp_dir}/staging"
mkdir -p "${staging_root}/dotfiles-${branch_ref}"
cp -R "${REPO_DIR}/." "${staging_root}/dotfiles-${branch_ref}/"
rm -rf "${staging_root}/dotfiles-${branch_ref}/.git" "${staging_root}/dotfiles-${branch_ref}/dist"
# Filename matches the URL path: {ref}.tar.gz (no dotfiles- prefix), same as GitHub.
tar -czf "${branch_archive_dir}/${branch_ref}.tar.gz" -C "$staging_root" "dotfiles-${branch_ref}"

# Serve over HTTP so BOOTSTRAP_ARCHIVE_BASE can point at it.
start_http_server "$web_root"

# Run the local bootstrap.sh directly with --ref pointing at the branch name.
bootstrap_out="$(
  BOOTSTRAP_ARCHIVE_BASE="http://127.0.0.1:${port}/archive" \
  HOME="$home_dir" \
  PATH="${fake_bin}:/usr/bin:/bin" \
  SHELL="/bin/zsh" \
  bash "${REPO_DIR}/bootstrap.sh" --ref "$branch_ref" 2>&1
)"

# 1) Checksum-skip warning must appear in output.
if ! printf '%s\n' "$bootstrap_out" | grep -q 'Skipping checksum verification'; then
  echo "Expected checksum-skip warning not found in bootstrap output." >&2
  echo "$bootstrap_out" >&2
  exit 1
fi

# 2) install.sh must have deployed ~/.zshrc into the isolated home.
if [[ ! -f "${home_dir}/.zshrc" ]]; then
  echo "Bootstrap branch-ref test did not deploy ~/.zshrc." >&2
  exit 1
fi

echo "Bootstrap branch ref test passed."
