#!/usr/bin/env bash
set -euo pipefail

# Validate split package inventory behavior for optional inference packages:
# 1) Default brew installs should include only the non-optional brew sections.
# 2) The inference section should only install when --install-inference is set.
# 3) The optional section should remain skipped in both cases.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test/lib/test-shims.sh
source "${SCRIPT_DIR}/lib/test-shims.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

HOME_DIR="${TMP_DIR}/home"
FAKE_BIN="${TMP_DIR}/bin"
PKG_DIR="${TMP_DIR}/packages"
MARKER="${TMP_DIR}/brew-installs.log"
mkdir -p "$HOME_DIR" "$FAKE_BIN" "$PKG_DIR"

cat > "${FAKE_BIN}/brew" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cmd="\${1:-}"
case "\$cmd" in
  shellenv)
    cat <<'OUT'
export HOMEBREW_PREFIX=/tmp/fakebrew
export HOMEBREW_CELLAR=/tmp/fakebrew/Cellar
export HOMEBREW_REPOSITORY=/tmp/fakebrew/Homebrew
export PATH=/tmp/fakebrew/bin:\$PATH
OUT
    ;;
  install)
    shift
    printf '%s\n' "\$*" >> "${MARKER}"
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

write_starship_shim "$FAKE_BIN"
write_pyenv_shim "$FAKE_BIN"
write_git_shim "$FAKE_BIN"
write_make_shim "$FAKE_BIN"

cat > "${PKG_DIR}/brew.yaml" <<'EOF'
base:
  - core-a
development:
  - dev-a
inference:
  - ollama
  - llmfit
optional:
  - optional-a
EOF

cat > "${PKG_DIR}/apt.yaml" <<'EOF'
apt_minimal:
  - apt-a
EOF

run_install() {
  HOME="$HOME_DIR" PATH="${FAKE_BIN}:$PATH" SHELL="/bin/zsh" \
    "${REPO_DIR}/install.sh" --no-apt --brew-only --yes --packages-dir "$PKG_DIR" --ref inference-test "$@" >/dev/null
}

# Default run: install only the standard brew sections.
run_install
if [[ ! -f "$MARKER" ]]; then
  echo "Expected brew install log missing after default run." >&2
  exit 1
fi

first_line="$(sed -n '1p' "$MARKER")"
if [[ "$first_line" != *"core-a"* || "$first_line" != *"dev-a"* ]]; then
  echo "Default brew install did not include the non-optional split sections." >&2
  exit 1
fi
if [[ "$first_line" == *"ollama"* || "$first_line" == *"llmfit"* || "$first_line" == *"optional-a"* ]]; then
  echo "Default brew install should skip inference and optional sections." >&2
  exit 1
fi

# Opt-in run: add the dedicated inference section without touching optional.
run_install --install-inference
line_count="$(wc -l < "$MARKER" | tr -d '[:space:]')"
if [[ "$line_count" -ne 3 ]]; then
  echo "Expected three brew install invocations (default, default rerun, inference opt-in), got ${line_count}." >&2
  exit 1
fi

second_line="$(sed -n '2p' "$MARKER")"
third_line="$(sed -n '3p' "$MARKER")"
if [[ "$second_line" != *"core-a"* || "$second_line" != *"dev-a"* ]]; then
  echo "Opt-in run should still install the standard brew sections." >&2
  exit 1
fi
if [[ "$third_line" != *"ollama"* || "$third_line" != *"llmfit"* ]]; then
  echo "Inference opt-in run did not install the inference section." >&2
  exit 1
fi
if [[ "$third_line" == *"optional-a"* ]]; then
  echo "Optional brew section should remain skipped during inference opt-in." >&2
  exit 1
fi

echo "Inference opt-in behavior checks passed."
