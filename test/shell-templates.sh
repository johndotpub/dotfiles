#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-shell-templates 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-templates.XXXXXX"
}

TMP_DIR="$(mktemp_dir)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "$HOME_DIR" "$FAKE_BIN"
setup_common_fake_bin "$FAKE_BIN"

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/bash"

# Install into an empty HOME and verify bash template is seeded.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag shell-template-test >/dev/null

if [[ ! -f "${HOME_DIR}/.bashrc" ]]; then
  echo "Expected ~/.bashrc template to be deployed." >&2
  exit 1
fi

# Simulate a login where brew is not in PATH but HOMEBREW_PREFIX is known.
prefix_brew="${TMP_DIR}/prefix/bin/brew"
mkdir -p "$(dirname "$prefix_brew")"
cat > "$prefix_brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "shellenv" ]]; then
  exit 1
fi
cat <<OUT
export HOMEBREW_PREFIX="${HOMEBREW_PREFIX}"
export PATH="${HOMEBREW_PREFIX}/bin:\$PATH"
OUT
EOF
chmod +x "$prefix_brew"

resolved_brew="$(
  HOME="$HOME_DIR" \
  PATH="/usr/bin:/bin" \
  HOMEBREW_PREFIX="${TMP_DIR}/prefix" \
  bash -c 'source "$HOME/.bashrc"; command -v brew'
)"

if [[ "$resolved_brew" != "${TMP_DIR}/prefix/bin/brew" ]]; then
  echo "Expected ~/.bashrc to resolve brew from HOMEBREW_PREFIX." >&2
  exit 1
fi

# Ensure zsh template also carries explicit fallback search logic.
if ! grep -q 'HOMEBREW_PREFIX' "${REPO_DIR}/skel/default/.zshrc"; then
  echo "Expected skel/default/.zshrc to include HOMEBREW_PREFIX fallback." >&2
  exit 1
fi

echo "Shell template checks passed."
