#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-brew-fail-bin 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-fail-bin.XXXXXX"
}

tmp_dir="$(mktemp_dir)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fake_prefix="${tmp_dir}/homebrew"
fake_bin="${fake_prefix}/bin"
mkdir -p "$fake_bin"

cat > "${fake_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "shellenv" ]]; then
  exit 1
fi
exit 1
EOF
chmod +x "${fake_bin}/brew"

# Keep PATH minimal and point HOMEBREW_PREFIX at a failing brew binary.
export PATH="/usr/bin:/bin"
export HOMEBREW_PREFIX="${fake_prefix}"

# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"

if setup_brew_env; then
  echo "setup_brew_env unexpectedly succeeded when brew binary shellenv failed"
  exit 1
fi

echo "brew binary failure path test passed."
