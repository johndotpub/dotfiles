#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Keep PATH minimal and force HOMEBREW_PREFIX to a controlled failing binary so
# global runner brew installs cannot influence this test.
export PATH="/usr/bin:/bin"

mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-brew-fail-fn 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-fail-fn.XXXXXX"
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
export HOMEBREW_PREFIX="${fake_prefix}"

# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"

# Simulate a callable brew command that fails for shellenv.
brew() {
  if [[ "${1:-}" == "shellenv" ]]; then
    return 1
  fi
  return 1
}

if setup_brew_env; then
  echo "setup_brew_env unexpectedly succeeded when brew shellenv failed"
  exit 1
fi

echo "brew shell function failure path test passed."
