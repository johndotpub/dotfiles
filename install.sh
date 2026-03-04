#!/usr/bin/env bash
set -euo pipefail

# Brew-first, idempotent installer for dotfiles.
# Usage: ./install.sh [--tag TAG] [--host HOST] [--pyver 3.12.12] [--create-home-pyver] [--install-inference] [--dry-run] [--force] [--brew-only] [--no-apt] [--verbose] [-y]

FORCE=0
CREATE_HOME_PYVER=0
INSTALL_INFERENCE=0
PYVER="3.12.12"
NO_APT=0
BREW_ONLY=0
DRY_RUN=0
ASSUME_YES=0
VERBOSE=0
HOST=""
TAG=""
FROM_RELEASE=0

# Track whether the user explicitly set values so inventory can provide defaults.
CLI_SET_PYVER=0
CLI_SET_CREATE_HOME_PYVER=0
CLI_SET_INSTALL_INFERENCE=0

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKEL_DIR="${REPO_DIR}/skel"
PKG_DIR="${REPO_DIR}/packages"
INVENTORY_DIR="${REPO_DIR}/inventory"
SKEL_PROFILE="default"

timestamp() { date +%Y%m%d%H%M%S; }

info() { printf 'ℹ️  %s\n' "$*"; }
ok() { printf '✅ %s\n' "$*"; }
warn() { printf '⚠️  %s\n' "$*"; }
err() { printf '❌ %s\n' "$*" >&2; }
debug() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    printf '🔎 %s\n' "$*"
  fi
}

format_cmd() {
  local out="" arg=""
  for arg in "$@"; do
    out+=" $(printf '%q' "$arg")"
  done
  printf '%s' "${out# }"
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: %s\n' "$(format_cmd "$@")"
    return 0
  fi
  [[ "$VERBOSE" -eq 1 ]] && printf '🔎 RUN: %s\n' "$(format_cmd "$@")"
  "$@"
}

run_pipe() {
  local pipeline="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: %s\n' "$pipeline"
    return 0
  fi
  [[ "$VERBOSE" -eq 1 ]] && printf '🔎 RUN: %s\n' "$pipeline"
  bash -lc "$pipeline"
}

usage() {
  cat <<EOF
install.sh [options]
Options:
  -h, --help                 Show this help
  -f, --force                Overwrite existing files without backup
      --create-home-pyver    Create ~/.python-version with --pyver value
      --pyver <ver>          Python version for ~/.python-version (default: ${PYVER})
      --install-inference    Install optional inference tools (ollama, llmfit)
      --no-apt               Skip apt installs
      --brew-only            Prefer brew only; skip apt fallback
      --dry-run              Print actions without executing
  -y, --yes                  Assume yes for prompts
      --verbose              Verbose logging
      --host <host>          Optional inventory overlay: inventory/hosts/<host>.yaml
      --tag <tag>            Release tag (informational)
      --from-release         Informational flag set by bootstrap
      --skel-dir <path>      Use alternate skel directory
      --packages-dir <path>  Use alternate packages directory
      --inventory-dir <path> Use alternate inventory directory

Behavior:
  - Existing files are preserved by default.
  - Use --force to replace existing files.
EOF
}

ARGS="$(getopt -o hfy --long help,force,create-home-pyver,pyver:,install-inference,no-apt,brew-only,dry-run,yes,verbose,host:,tag:,from-release,skel-dir:,packages-dir:,inventory-dir: -n "$(basename "$0")" -- "$@")" || {
  usage
  exit 1
}
eval set -- "$ARGS"
while true; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -f|--force) FORCE=1; shift ;;
    --create-home-pyver) CREATE_HOME_PYVER=1; CLI_SET_CREATE_HOME_PYVER=1; shift ;;
    --pyver) PYVER="$2"; CLI_SET_PYVER=1; shift 2 ;;
    --install-inference) INSTALL_INFERENCE=1; CLI_SET_INSTALL_INFERENCE=1; shift ;;
    --no-apt) NO_APT=1; shift ;;
    --brew-only) BREW_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --host) HOST="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --from-release) FROM_RELEASE=1; shift ;;
    --skel-dir) SKEL_DIR="$2"; shift 2 ;;
    --packages-dir) PKG_DIR="$2"; shift 2 ;;
    --inventory-dir) INVENTORY_DIR="$2"; shift 2 ;;
    --) shift; break ;;
    *) usage; exit 1 ;;
  esac
done

debug "repo_dir=${REPO_DIR}"
debug "tag=${TAG:-<none>}"
debug "host=${HOST:-<none>}"
debug "from_release=${FROM_RELEASE}"

SUDO_BIN=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO_BIN="sudo"
fi

run_root() {
  if [[ -n "$SUDO_BIN" ]]; then
    run "$SUDO_BIN" "$@"
  else
    run "$@"
  fi
}

confirm_or_die() {
  local prompt="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N] " ans
  case "$ans" in
    [Yy]*) return 0 ;;
    *) err "Aborted."; exit 1 ;;
  esac
}

bool_to_int() {
  case "${1,,}" in
    true|yes|y|on|1) printf '1' ;;
    false|no|n|off|0) printf '0' ;;
    *) printf '%s' "$2" ;;
  esac
}

yaml_get_scalar() {
  local key="$1"
  local file="$2"
  awk -F': *' -v k="$key" '$1 == k {print $2; exit}' "$file" | tr -d "\"'"
}

apply_inventory_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  debug "Applying inventory file: $file"

  local val=""
  if [[ "$CLI_SET_PYVER" -eq 0 ]]; then
    val="$(yaml_get_scalar "pyver" "$file" || true)"
    [[ -n "$val" ]] && PYVER="$val"
  fi
  if [[ "$CLI_SET_CREATE_HOME_PYVER" -eq 0 ]]; then
    val="$(yaml_get_scalar "create_home_pyver" "$file" || true)"
    [[ -n "$val" ]] && CREATE_HOME_PYVER="$(bool_to_int "$val" "$CREATE_HOME_PYVER")"
  fi
  if [[ "$CLI_SET_INSTALL_INFERENCE" -eq 0 ]]; then
    val="$(yaml_get_scalar "install_inference" "$file" || true)"
    [[ -n "$val" ]] && INSTALL_INFERENCE="$(bool_to_int "$val" "$INSTALL_INFERENCE")"
  fi
  val="$(yaml_get_scalar "skel_profile" "$file" || true)"
  [[ -n "$val" ]] && SKEL_PROFILE="$val"
}

read_package_file() {
  local file="$1"
  awk '!/^[[:space:]]*($|#)/{print $1}' "$file"
}

backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      run rm -rf -- "$path"
      debug "Removed existing path (force): $path"
    else
      local bak="${path}.bak.$(timestamp)"
      run mv -- "$path" "$bak"
      debug "Backed up ${path} -> ${bak}"
    fi
  fi
}

ensure_brew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    eval "$(brew shellenv)"
    return 0
  fi
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    # shellcheck disable=SC2046
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [[ -x "/usr/local/bin/brew" ]]; then
    # shellcheck disable=SC2046
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  return 1
}

install_brew_if_missing() {
  if ensure_brew_shellenv; then
    ok "Homebrew is available."
    return 0
  fi
  info "🍺 Installing Homebrew..."
  run_pipe "NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  if [[ "$DRY_RUN" -eq 1 ]]; then
    debug "Dry-run mode: skipping post-install brew shellenv verification"
    return 0
  fi
  ensure_brew_shellenv || {
    err "Failed to initialize Homebrew after install."
    exit 1
  }
  ok "Homebrew installed and initialized."
}

install_apt_baseline() {
  local pkgs=(
    build-essential curl wget ca-certificates gnupg lsb-release locales git pkg-config make gcc g++
    zlib1g-dev libssl-dev libbz2-dev libreadline-dev libsqlite3-dev libncurses5-dev libncursesw5-dev
    xz-utils tk-dev libffi-dev liblzma-dev
  )
  if ! command -v apt-get >/dev/null 2>&1; then
    debug "apt-get not found; skipping apt baseline"
    return 0
  fi
  info "📦 Installing minimal apt prerequisites..."
  run_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${pkgs[@]}"
}

install_apt_from_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if ! command -v apt-get >/dev/null 2>&1; then
    debug "apt-get not found; skipping apt fallback installs"
    return 0
  fi
  mapfile -t pkgs < <(read_package_file "$file")
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  info "📦 Installing apt fallback packages..."
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_brew_from_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  mapfile -t pkgs < <(read_package_file "$file")
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  info "🍺 Installing brew packages..."
  run brew install "${pkgs[@]}" || true
}

deploy_skel_profile() {
  local profile="$1"
  local src_root="${SKEL_DIR}/${profile}"
  if [[ ! -d "$src_root" ]]; then
    warn "No skel profile found at ${src_root}; skipping deployment."
    return 0
  fi
  info "🧩 Deploying skel profile: ${profile}"
  shopt -s dotglob nullglob
  local src base dest
  for src in "${src_root}"/*; do
    base="$(basename "$src")"
    dest="${HOME}/${base}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      if [[ "$FORCE" -eq 1 ]]; then
        backup_path "$dest"
        run cp -a "$src" "$dest"
        debug "Processed ${dest} with force"
      elif [[ -d "$src" && -d "$dest" ]]; then
        info "↪️  Keeping existing ${dest} (adding missing files only)"
        if [[ "$DRY_RUN" -eq 1 ]]; then
          printf '🧪 DRY: cp -a --update=none %q %q\n' "${src}/." "${dest}/"
        else
          cp -a --update=none "${src}/." "${dest}/"
        fi
      else
        info "↪️  Keeping existing ${dest}"
      fi
      continue
    fi
    run cp -a "$src" "$dest"
    debug "Processed ${dest}"
  done
  shopt -u dotglob nullglob
}

print_checks() {
  printf '🚦 Post-install checks\n'
  if command -v brew >/dev/null 2>&1; then
    printf '🟢 brew: %s\n' "$(brew --version | awk 'NR==1{print $0}')"
  else
    printf '🔴 brew: not found\n'
  fi

  if command -v starship >/dev/null 2>&1; then
    printf '🟢 starship: %s\n' "$(starship --version 2>/dev/null || echo 'available')"
  else
    printf '🔴 starship: not found\n'
  fi

  if command -v pyenv >/dev/null 2>&1; then
    printf '🟢 pyenv: %s\n' "$(pyenv --version 2>/dev/null || echo 'available')"
  else
    printf '🟡 pyenv: not found (optional)\n'
  fi

  if command -v python3 >/dev/null 2>&1; then
    printf '🟢 python3: %s %s\n' "$(command -v python3)" "$(python3 --version 2>/dev/null || true)"
  else
    printf '🔴 python3: not found\n'
  fi
}

info "🚀 Starting dotfiles install..."
apply_inventory_file "${INVENTORY_DIR}/default.yaml"
if [[ -n "$HOST" ]]; then
  host_file="${INVENTORY_DIR}/hosts/${HOST}.yaml"
  if [[ ! -f "$host_file" ]]; then
    err "Host profile not found: ${host_file}"
    exit 1
  fi
  apply_inventory_file "$host_file"
fi

debug "effective_pyver=${PYVER}"
debug "effective_create_home_pyver=${CREATE_HOME_PYVER}"
debug "effective_install_inference=${INSTALL_INFERENCE}"
debug "effective_skel_profile=${SKEL_PROFILE}"

if [[ "$NO_APT" -eq 0 && "$BREW_ONLY" -eq 0 ]]; then
  install_apt_baseline
  if command -v locale-gen >/dev/null 2>&1; then
    run_root locale-gen en_US.UTF-8 || true
  fi
  if command -v update-locale >/dev/null 2>&1; then
    run_root update-locale LANG=en_US.UTF-8 || true
  fi
else
  debug "Skipping apt baseline installs"
fi

install_brew_if_missing

BREW_PKGS_FILE="${PKG_DIR}/brew-packages.txt"
if [[ -f "$BREW_PKGS_FILE" ]]; then
  install_brew_from_file "$BREW_PKGS_FILE"
fi

if [[ "$BREW_ONLY" -eq 0 && "$NO_APT" -eq 0 ]]; then
  APT_FALLBACK_FILE="${PKG_DIR}/apt-minimal.txt"
  if [[ -f "$APT_FALLBACK_FILE" ]]; then
    install_apt_from_file "$APT_FALLBACK_FILE" || true
  fi
fi

if ! command -v uv >/dev/null 2>&1; then
  info "🐍 Installing uv..."
  run_pipe "curl -LsSf https://astral.sh/uv/install.sh | sh"
else
  ok "uv is available."
fi

if [[ "$INSTALL_INFERENCE" -eq 1 ]]; then
  info "🤖 Installing optional inference tools..."
  run_pipe "curl -fsSL https://ollama.ai/install.sh | sh || true"
  run_pipe "curl -fsSL https://llmfit.axjns.dev/install.sh | sh || true"
fi

if command -v pyenv >/dev/null 2>&1; then
  if pyenv versions --bare | grep -Fxq "$PYVER"; then
    ok "pyenv has ${PYVER} installed."
  else
    warn "pyenv version ${PYVER} is not installed (installer does not manage pyenv versions)."
  fi
fi

deploy_skel_profile "$SKEL_PROFILE"

if [[ "$CREATE_HOME_PYVER" -eq 1 ]]; then
  pyver_file="${HOME}/.python-version"
  if [[ -f "$pyver_file" && "$FORCE" -eq 0 ]]; then
    info "↪️  Keeping existing ${pyver_file}"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: echo %q > %q\n' "$PYVER" "$pyver_file"
  else
    printf '%s\n' "$PYVER" > "$pyver_file"
    ok "Configured ${pyver_file} (${PYVER})"
  fi
fi

if [[ "${SHELL##*/}" != "zsh" ]] && command -v zsh >/dev/null 2>&1; then
  if [[ "$ASSUME_YES" -eq 0 ]]; then
    confirm_or_die "Change default shell to zsh?"
  fi
  run chsh -s "$(command -v zsh)" || true
fi

print_checks
ok "Install script finished."
