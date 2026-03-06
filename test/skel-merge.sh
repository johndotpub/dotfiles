#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Build isolated environment and custom skel fixture tree.
HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
CUSTOM_SKEL="${TMP_DIR}/skel"
mkdir -p "${HOME_DIR}/.config" "$FAKE_BIN" "${CUSTOM_SKEL}/default/.config"

# Shared shims cover brew/starship/pyenv/git/make behavior.
setup_common_fake_bin "$FAKE_BIN"

# Create fixture files:
# - keep.conf exists in both HOME and skel (HOME should win)
# - new.conf exists only in skel (should be copied)
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

# Run installer against custom skel to validate merge semantics.
"${REPO_DIR}/install.sh" --no-apt --brew-only --yes --skel-dir "${CUSTOM_SKEL}" --tag merge-test >/dev/null

# Existing file content must remain unchanged.
if ! grep -Fxq "from-home" "${HOME_DIR}/.config/keep.conf"; then
  echo "Expected existing .config/keep.conf content to be preserved." >&2
  exit 1
fi

# Missing file must be copied in from skel profile.
if ! grep -Fxq "new-file" "${HOME_DIR}/.config/new.conf"; then
  echo "Expected missing .config/new.conf to be copied from skel." >&2
  exit 1
fi

echo "Skel merge behavior checks passed."
