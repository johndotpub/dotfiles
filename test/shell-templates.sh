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

chsh_log="${TMP_DIR}/chsh.log"
cat > "${FAKE_BIN}/zsh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/zsh"

cat > "${FAKE_BIN}/chsh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${CHSH_LOG_FILE}"
exit 0
EOF
chmod +x "${FAKE_BIN}/chsh"

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/bash"
export CHSH_LOG_FILE="${chsh_log}"

# Install into an empty HOME and verify bash template is seeded.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --tag shell-template-test >/dev/null

if [[ ! -f "${HOME_DIR}/.bashrc" ]]; then
  echo "Expected ~/.bashrc template to be deployed." >&2
  exit 1
fi

if [[ ! -f "${chsh_log}" ]]; then
  echo "Expected installer to attempt non-interactive chsh to zsh." >&2
  exit 1
fi
if ! grep -q -- "-s" "${chsh_log}"; then
  echo "Expected chsh invocation to include shell switch flag." >&2
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

# Simulate a login where brew exists in PATH but shellenv fails there, and
# fallback probing should recover via HOMEBREW_PREFIX candidate.
bad_bin="${TMP_DIR}/badbin"
mkdir -p "$bad_bin"
cat > "${bad_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "shellenv" ]]; then
  exit 1
fi
exit 1
EOF
chmod +x "${bad_bin}/brew"

resolved_brew_with_bad_path="$(
  HOME="$HOME_DIR" \
  PATH="${bad_bin}:/usr/bin:/bin" \
  HOMEBREW_PREFIX="${TMP_DIR}/prefix" \
  bash -c 'source "$HOME/.bashrc"; command -v brew'
)"

if [[ "$resolved_brew_with_bad_path" != "${TMP_DIR}/prefix/bin/brew" ]]; then
  echo "Expected ~/.bashrc fallback probing when PATH brew shellenv fails." >&2
  exit 1
fi

# Ensure the brew candidate logic is present in the shared brew-init.sh snippet.
# .zshrc and .bashrc both source this file instead of duplicating the block.
if ! grep -q 'brew_candidates=(' "${REPO_DIR}/skel/default/.config/brew-init.sh"; then
  echo "Expected skel/default/.config/brew-init.sh to include brew candidate probing." >&2
  exit 1
fi
if ! grep -q 'brew_env_initialized=0' "${REPO_DIR}/skel/default/.config/brew-init.sh"; then
  echo "Expected skel/default/.config/brew-init.sh to track brew init success state." >&2
  exit 1
fi
expected_loop="for brew_bin in \"\${brew_candidates[@]}\""
if ! grep -Fq "$expected_loop" "${REPO_DIR}/skel/default/.config/brew-init.sh"; then
  echo "Expected skel/default/.config/brew-init.sh fallback loop over brew candidates." >&2
  exit 1
fi

echo "Shell template checks passed."
