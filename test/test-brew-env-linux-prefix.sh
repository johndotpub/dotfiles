#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

tmp_dir="$(mktemp -d)"
cleanup() {
  /bin/rm -rf "$tmp_dir"
}
trap cleanup EXIT

fake_prefix="${tmp_dir}/homebrew"
fake_bin="${fake_prefix}/bin"
mkdir -p "$fake_bin"

cat > "${fake_bin}/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" != "shellenv" ]]; then
  echo "unexpected command: $*" >&2
  exit 1
fi
cat <<OUT
export HOMEBREW_PREFIX="__FAKE_PREFIX__"
export PATH="__FAKE_PREFIX__/bin:\$PATH"
OUT
EOF
/bin/sed -i "s|__FAKE_PREFIX__|${fake_prefix}|g" "${fake_bin}/brew"
chmod +x "${fake_bin}/brew"

export PATH="/usr/bin:/bin"
export HOMEBREW_PREFIX="${fake_prefix}"

# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"
setup_brew_env

if [[ "${HOMEBREW_PREFIX}" != "${fake_prefix}" ]]; then
  echo "HOMEBREW_PREFIX not set correctly after setup_brew_env"
  exit 1
fi

case ":${PATH}:" in
  *":${fake_bin}:"*) ;;
  *)
    echo "setup_brew_env did not inject fake brew bin into PATH"
    exit 1
    ;;
esac

echo "brew env linux-prefix helper test passed."
