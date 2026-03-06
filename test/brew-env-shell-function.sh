#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cross-platform temp directory helper (GNU + BSD mktemp variants).
mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-brew-fn 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-fn.XXXXXX"
}

tmp_dir="$(mktemp_dir)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fake_prefix="${tmp_dir}/brew-fn"
mkdir -p "${fake_prefix}/bin"

# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"

# Simulate environments where brew is a shell function (`command -v brew`
# returns "brew" rather than an executable path).
brew() {
  if [[ "${1:-}" == "shellenv" ]]; then
    cat <<OUT
export HOMEBREW_PREFIX="${fake_prefix}"
export PATH="${fake_prefix}/bin:\$PATH"
OUT
    return 0
  fi
  return 1
}

export PATH="/usr/bin:/bin"
if ! setup_brew_env; then
  echo "setup_brew_env failed for brew shell function"
  exit 1
fi

if [[ "${HOMEBREW_PREFIX:-}" != "${fake_prefix}" ]]; then
  echo "HOMEBREW_PREFIX not exported from brew shell function"
  exit 1
fi

case ":${PATH}:" in
  *":${fake_prefix}/bin:"*) ;;
  *)
    echo "setup_brew_env did not apply PATH from brew shell function"
    exit 1
    ;;
esac

echo "brew env shell function helper test passed."
