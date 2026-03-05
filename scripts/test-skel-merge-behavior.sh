#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
CUSTOM_SKEL="${TMP_DIR}/skel"
mkdir -p "${HOME_DIR}/.config" "$FAKE_BIN" "${CUSTOM_SKEL}/default/.config"

cat > "${FAKE_BIN}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  shellenv)
    cat <<'OUT'
export PATH=/tmp/fakebrew/bin:$PATH
OUT
    ;;
  --version)
    echo "Homebrew 4.4.0"
    ;;
  *)
    exit 0
    ;;
esac
EOF
chmod +x "${FAKE_BIN}/brew"

cat > "${FAKE_BIN}/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "preset" && "${2:-}" == "--help" ]]; then
  echo "starship preset help"
  exit 0
fi
if [[ "${1:-}" == "preset" && "${2:-}" == "tokyo-night" && "${3:-}" == "-o" ]]; then
  target="${4:-}"
  mkdir -p "$(dirname "$target")"
  printf '%s\n' '# tokyo-night preset test config' > "$target"
  exit 0
fi
echo "starship 1.0.0-test"
EOF
chmod +x "${FAKE_BIN}/starship"

cat > "${FAKE_BIN}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "clone" ]]; then
  target="${@: -1}"
  mkdir -p "$target"
  cat > "${target}/Makefile" <<'OUT'
install:
	@echo "nanorc install"
OUT
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/git"

cat > "${FAKE_BIN}/make" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${FAKE_BIN}/make"

cat > "${FAKE_BIN}/pyenv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "versions" ]]; then
  exit 0
fi
echo "pyenv 2.4.0-test"
EOF
chmod +x "${FAKE_BIN}/pyenv"

cat > "${HOME_DIR}/.config/keep.conf" <<'EOF'
from-home
EOF

cat > "${CUSTOM_SKEL}/default/.config/keep.conf" <<'EOF'
from-skel
EOF

cat > "${CUSTOM_SKEL}/default/.config/new.conf" <<'EOF'
new-file
EOF

export HOME="$HOME_DIR"
export PATH="${FAKE_BIN}:$PATH"
export SHELL="/bin/zsh"

"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --skel-dir "${CUSTOM_SKEL}" --tag merge-test >/dev/null

if ! grep -Fxq "from-home" "${HOME_DIR}/.config/keep.conf"; then
  echo "Expected existing .config/keep.conf content to be preserved." >&2
  exit 1
fi

if ! grep -Fxq "new-file" "${HOME_DIR}/.config/new.conf"; then
  echo "Expected missing .config/new.conf to be copied from skel." >&2
  exit 1
fi

echo "Skel merge behavior checks passed."
