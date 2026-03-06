#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TMP_DIRS=()

cleanup() {
  local dir=""
  for dir in "${TMP_DIRS[@]:-}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

# Cross-platform temp directory helper (GNU + BSD mktemp variants).
mktemp_dir() {
  mktemp -d 2>/dev/null || mktemp -d -t dotfiles-brew-env 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/dotfiles-brew-env.XXXXXX"
}

# Build a fake brew binary that either emits shellenv exports or fails.
write_fake_brew() {
  local target="$1"
  local mode="$2"
  local prefix="$3"
  mkdir -p "$(dirname "$target")"

  if [[ "$mode" == "ok" ]]; then
    cat > "$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" != "shellenv" ]]; then
  exit 1
fi
cat <<OUT
export HOMEBREW_PREFIX="${prefix}"
export PATH="${prefix}/bin:\$PATH"
OUT
EOF
  else
    cat > "$target" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 1
EOF
  fi
  chmod +x "$target"
}

assert_path_contains() {
  local needle="$1"
  case ":${PATH}:" in
    *":${needle}:"*) ;;
    *)
      echo "PATH does not contain expected entry: ${needle}" >&2
      return 1
      ;;
  esac
}

# Scenario: resolve brew via HOMEBREW_PREFIX binary path.
scenario_prefix_binary() {
  local tmp_dir fake_prefix fake_brew
  tmp_dir="$(mktemp_dir)"
  TMP_DIRS+=("$tmp_dir")

  fake_prefix="${tmp_dir}/homebrew"
  fake_brew="${fake_prefix}/bin/brew"
  write_fake_brew "$fake_brew" ok "$fake_prefix"

  export PATH="/usr/bin:/bin"
  export HOMEBREW_PREFIX="$fake_prefix"
  # shellcheck source=scripts/lib/brew-env.sh
  source "${REPO_DIR}/scripts/lib/brew-env.sh"
  setup_brew_env

  [[ "${HOMEBREW_PREFIX:-}" == "$fake_prefix" ]]
  assert_path_contains "${fake_prefix}/bin"
}

# Scenario: resolve brew via shell function implementation.
scenario_shell_function() {
  local tmp_dir fake_prefix
  tmp_dir="$(mktemp_dir)"
  TMP_DIRS+=("$tmp_dir")
  fake_prefix="${tmp_dir}/brew-fn"
  mkdir -p "${fake_prefix}/bin"

  export PATH="/usr/bin:/bin"
  unset HOMEBREW_PREFIX || true
  # shellcheck source=scripts/lib/brew-env.sh
  source "${REPO_DIR}/scripts/lib/brew-env.sh"

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

  setup_brew_env
  [[ "${HOMEBREW_PREFIX:-}" == "$fake_prefix" ]]
  assert_path_contains "${fake_prefix}/bin"
}

# Scenario: shell function fails and explicit prefix binary fails -> overall fail.
scenario_shell_function_failure() {
  local tmp_dir fake_prefix fake_brew
  tmp_dir="$(mktemp_dir)"
  TMP_DIRS+=("$tmp_dir")

  fake_prefix="${tmp_dir}/homebrew"
  fake_brew="${fake_prefix}/bin/brew"
  write_fake_brew "$fake_brew" fail "$fake_prefix"

  export PATH="/usr/bin:/bin"
  export HOMEBREW_PREFIX="$fake_prefix"
  # shellcheck source=scripts/lib/brew-env.sh
  source "${REPO_DIR}/scripts/lib/brew-env.sh"

  brew() {
    return 1
  }

  if setup_brew_env; then
    echo "setup_brew_env unexpectedly succeeded for failing shell function path" >&2
    return 1
  fi
}

# Scenario: explicit HOMEBREW_PREFIX binary fails -> overall fail.
scenario_binary_failure() {
  local tmp_dir fake_prefix fake_brew
  tmp_dir="$(mktemp_dir)"
  TMP_DIRS+=("$tmp_dir")

  fake_prefix="${tmp_dir}/homebrew"
  fake_brew="${fake_prefix}/bin/brew"
  write_fake_brew "$fake_brew" fail "$fake_prefix"

  export PATH="/usr/bin:/bin"
  export HOMEBREW_PREFIX="$fake_prefix"
  # shellcheck source=scripts/lib/brew-env.sh
  source "${REPO_DIR}/scripts/lib/brew-env.sh"

  if setup_brew_env; then
    echo "setup_brew_env unexpectedly succeeded for failing binary path" >&2
    return 1
  fi
}

scenario_prefix_binary
scenario_shell_function
scenario_shell_function_failure
scenario_binary_failure

echo "brew env scenarios passed."
