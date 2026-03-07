#!/usr/bin/env bash
set -euo pipefail

# Validate that nanorc clone failures do not abort the installer.
# Nano syntax highlighting is optional enhancement and should fail gracefully.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
ORIG_PATH="$PATH"
mkdir -p "$HOME_DIR" "$FAKE_BIN"

setup_common_fake_bin "$FAKE_BIN"

# Override git shim: fail clone only for ~/.nano target, succeed for others.
cat > "${FAKE_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  target="${@: -1}"
  if [[ "$(basename "$target")" == ".nano" ]]; then
    exit 1
  fi
  mkdir -p "$target"
  if [[ "$(basename "$target")" == ".tmux" ]]; then
    cat > "${target}/.tmux.conf" <<'OUT'
# fake oh-my-tmux config
OUT
    cat > "${target}/.tmux.conf.local" <<'OUT'
# fake oh-my-tmux local config
OUT
    exit 0
  fi
  cat > "${target}/Makefile" <<'OUT'
install:
	@true
OUT
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/git"

HOME="$HOME_DIR" PATH="${FAKE_BIN}:${ORIG_PATH}" SHELL="/bin/zsh" \
  "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --ref nanorc-failure >/dev/null

# Installer should still apply primary configs even when nanorc clone fails.
test -f "${HOME_DIR}/.zshrc"
test -L "${HOME_DIR}/.tmux.conf"
test -f "${HOME_DIR}/.config/starship.toml"

echo "Nanorc optional failure handling checks passed."
