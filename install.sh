#!/usr/bin/env bash
set -euo pipefail

# Brew-first, idempotent installer for dotfiles.
# Usage: ./install.sh [--tag TAG] [--host HOST] [--pyver 3.12.12] [--create-home-pyver] [--install-inference] [--dry-run] [--override] [--brew-only] [--no-apt] [--verbose] [-y]
#
# High-level flow:
#   1) Parse CLI flags and resolve effective config (CLI + inventory)
#   2) Prepare base dependencies (optional apt + brew bootstrap)
#   3) Install package sets (brew first, apt fallback)
#   4) Apply user-facing config (skel files, starship, nano syntax)
#   5) Run post-install checks and exit with clear status logs

OVERRIDE=0
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

next_backup_path() {
  local base="$1"
  local ts candidate i
  ts="$(timestamp)"
  candidate="${base}.bak.${ts}"
  i=0
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    i=$((i + 1))
    candidate="${base}.bak.${ts}.${i}"
  done
  printf '%s\n' "$candidate"
}

# ------------------------------------------------------------------------------
# Logging and command execution helpers
# ------------------------------------------------------------------------------
# - info/ok/warn/err: user-facing status messages
# - debug: verbose-only internals
# - run/run_pipe: DRY-RUN-aware command execution wrappers
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
  bash -c "$pipeline"
}

usage() {
  cat <<EOF
install.sh [options]
Options:
  -h, --help                 Show this help
  -f, --override             Overwrite existing files (with .bak.<date> backup)
      --force                Backward-compatible alias for --override
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
  - Use --override to replace existing files (always backed up first).
EOF
}

# Manual argument parsing keeps behavior portable across GNU/Linux, WSL, and macOS.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -f|--override|--force)
      OVERRIDE=1
      shift
      ;;
    --create-home-pyver)
      CREATE_HOME_PYVER=1
      CLI_SET_CREATE_HOME_PYVER=1
      shift
      ;;
    --pyver)
      [[ $# -ge 2 ]] || { err "--pyver requires a value"; exit 1; }
      PYVER="$2"
      CLI_SET_PYVER=1
      shift 2
      ;;
    --install-inference)
      INSTALL_INFERENCE=1
      CLI_SET_INSTALL_INFERENCE=1
      shift
      ;;
    --no-apt)
      NO_APT=1
      shift
      ;;
    --brew-only)
      BREW_ONLY=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
      shift
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --host)
      [[ $# -ge 2 ]] || { err "--host requires a value"; exit 1; }
      HOST="$2"
      shift 2
      ;;
    --tag)
      [[ $# -ge 2 ]] || { err "--tag requires a value"; exit 1; }
      TAG="$2"
      shift 2
      ;;
    --from-release)
      FROM_RELEASE=1
      shift
      ;;
    --skel-dir)
      [[ $# -ge 2 ]] || { err "--skel-dir requires a value"; exit 1; }
      SKEL_DIR="$2"
      shift 2
      ;;
    --packages-dir)
      [[ $# -ge 2 ]] || { err "--packages-dir requires a value"; exit 1; }
      PKG_DIR="$2"
      shift 2
      ;;
    --inventory-dir)
      [[ $# -ge 2 ]] || { err "--inventory-dir requires a value"; exit 1; }
      INVENTORY_DIR="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Runtime diagnostics to make troubleshooting easier when verbose is enabled.
debug "repo_dir=${REPO_DIR}"
debug "tag=${TAG:-<none>}"
debug "host=${HOST:-<none>}"
debug "from_release=${FROM_RELEASE}"

SUDO_BIN=""
if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  SUDO_BIN="sudo"
fi

# Run a command with elevated privileges when needed.
# We keep this wrapper centralized so dry-run and verbose logging still work.
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
  local normalized
  normalized="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
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
    local bak
    bak="$(next_backup_path "$path")"
    run mv "$path" "$bak"
    debug "Backed up ${path} -> ${bak}"
  fi
}

backup_copy() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local bak
    bak="$(next_backup_path "$path")"
    run cp -Rp "$path" "$bak"
    debug "Backed up copy ${path} -> ${bak}"
  fi
}

copy_item() {
  local src="$1"
  local dest="$2"
  run cp -Rp "$src" "$dest"
}

merge_dir_without_overwrite() {
  local src="$1"
  local dest="$2"
  if command -v rsync >/dev/null 2>&1; then
    run rsync -a --ignore-existing "${src}/" "${dest}/"
  else
    run cp -R -n "${src}/." "${dest}/"
  fi
}

ensure_brew_shellenv() {
  # Brew may already be in PATH (preferred). The explicit fallbacks handle
  # standard macOS locations when PATH has not yet been updated in this shell.
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
  if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1 && [[ "$NO_APT" -eq 0 ]] && [[ "$BREW_ONLY" -eq 0 ]]; then
      info "curl not found; installing via apt-get for Homebrew bootstrap..."
      run_root env DEBIAN_FRONTEND=noninteractive apt-get update -y
      run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates
    else
      err "curl is required to install Homebrew but is not available."
      err "Install curl manually, or re-run without --no-apt/--brew-only so it can be installed automatically."
      exit 1
    fi
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
  local pkgs=()
  local pkg=""
  while IFS= read -r pkg; do
    pkgs+=("$pkg")
  done < <(read_package_file "$file")
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  info "📦 Installing apt fallback packages..."
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
}

install_brew_from_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local pkgs=()
  local pkg=""
  while IFS= read -r pkg; do
    pkgs+=("$pkg")
  done < <(read_package_file "$file")
  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    return 0
  fi
  info "🍺 Installing brew packages..."
  if ! run brew install "${pkgs[@]}"; then
    warn "brew install failed for one or more packages listed in ${file}. Review output and retry."
    return 1
  fi
}

deploy_skel_profile() {
  # Deploy policy:
  # - default: preserve existing files and only fill missing content
  # - --override: replace existing targets after creating .bak.<timestamp>
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
      if [[ "$OVERRIDE" -eq 1 ]]; then
        backup_path "$dest"
        copy_item "$src" "$dest"
        debug "Processed ${dest} with override"
      elif [[ -d "$src" && -d "$dest" ]]; then
        info "↪️  Keeping existing ${dest} (adding missing files only)"
        merge_dir_without_overwrite "$src" "$dest"
      else
        info "↪️  Keeping existing ${dest}"
      fi
      continue
    fi
    copy_item "$src" "$dest"
    debug "Processed ${dest}"
  done
  shopt -u dotglob nullglob
}

configure_starship_prompt() {
  # Prefer the official preset command when available so users get the
  # canonical upstream style. Fall back to the bundled preset file otherwise.
  local target="${HOME}/.config/starship.toml"
  local fallback="${SKEL_DIR}/${SKEL_PROFILE}/.config/starship.toml"

  if [[ -f "$target" && "$OVERRIDE" -eq 0 ]]; then
    info "↪️  Keeping existing ${target}"
    return 0
  fi

  if [[ -f "$target" && "$OVERRIDE" -eq 1 ]]; then
    backup_path "$target"
  fi

  run mkdir -p "${HOME}/.config"

  if command -v starship >/dev/null 2>&1 && starship preset --help >/dev/null 2>&1; then
    run starship preset tokyo-night -o "$target"
    ok "Configured starship preset: tokyo-night"
    return 0
  fi

  if [[ -f "$fallback" ]]; then
    copy_item "$fallback" "$target"
    warn "starship preset command unavailable; applied fallback tokyo-night config."
    return 0
  fi

  warn "starship config not written (no preset command and no fallback file)."
}

configure_nano_syntax() {
  # nanorc setup is intentionally conservative:
  # - existing ~/.nanorc is left untouched by default
  # - override mode appends include after creating a backup copy
  local nano_dir="${HOME}/.nano"
  local nano_rc="${HOME}/.nanorc"
  local include_line='include ~/.nano/*.nanorc'

  info "📝 Ensuring nano syntax highlighting..."
  if [[ ! -d "$nano_dir" ]]; then
    run git clone --depth 1 https://github.com/scopatz/nanorc.git "$nano_dir"
  else
    info "↪️  Keeping existing ${nano_dir}"
  fi

  if [[ -d "$nano_dir" ]]; then
    run make -C "$nano_dir" install || true
  fi

  if [[ -f "$nano_rc" ]]; then
    if grep -Fxq "$include_line" "$nano_rc"; then
      debug "${nano_rc} already includes nanorc syntax files."
      return 0
    fi
    if [[ "$OVERRIDE" -eq 1 ]]; then
      backup_copy "$nano_rc"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '🧪 DRY: printf %q >> %q\n' "${include_line}\n" "$nano_rc"
      else
        printf '\n%s\n' "$include_line" >> "$nano_rc"
      fi
      ok "Updated ${nano_rc} to include nanorc syntax files."
    else
      info "↪️  Keeping existing ${nano_rc} (use --override to append nanorc include)"
    fi
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: printf %q > %q\n' "${include_line}\n" "$nano_rc"
  else
    printf '%s\n' "$include_line" > "$nano_rc"
  fi
  ok "Configured ${nano_rc} with nanorc include."
}

ensure_zsh_pyenv_plugin() {
  local zsh_dir="${HOME}/.oh-my-zsh"
  local custom_dir="${ZSH_CUSTOM:-${zsh_dir}/custom}"
  local custom_plugin_dir="${custom_dir}/plugins/zsh-pyenv"
  local built_in_plugin_dir="${zsh_dir}/plugins/zsh-pyenv"

  if [[ ! -d "$zsh_dir" ]]; then
    debug "Oh My Zsh not found; skipping zsh-pyenv plugin install."
    return 0
  fi

  if [[ -d "$custom_plugin_dir" || -d "$built_in_plugin_dir" ]]; then
    info "↪️  zsh-pyenv plugin already available."
    return 0
  fi

  info "🧩 Installing zsh-pyenv plugin for Oh My Zsh..."
  run mkdir -p "${custom_dir}/plugins"
  if ! run git clone --depth 1 https://github.com/mattberther/zsh-pyenv.git "$custom_plugin_dir"; then
    warn "Could not install zsh-pyenv plugin automatically. You can install it later manually."
  fi
}

print_checks() {
  # Traffic-light output gives an easy visual summary of final state.
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

  if command -v nano >/dev/null 2>&1; then
    printf '🟢 nano: %s\n' "$(nano --version 2>/dev/null | awk 'NR==1{print $0}')"
  else
    printf '🟡 nano: not found (optional)\n'
  fi
}

info "🚀 Starting dotfiles install..."
# Inventory precedence: defaults first, optional host overlay second.
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

# Optional apt path for Linux hosts. Disabled in brew-only or no-apt modes.
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

# Install package manifests.
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

# uv is useful for modern Python tooling workflows.
if ! command -v uv >/dev/null 2>&1; then
  info "🐍 Installing uv..."
  if command -v brew >/dev/null 2>&1; then
    if ! run brew install uv; then
      warn "brew install uv failed; falling back to upstream installer script."
      run_pipe "curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
  else
    run_pipe "curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi
else
  ok "uv is available."
fi

# Inference tools are explicitly opt-in.
if [[ "$INSTALL_INFERENCE" -eq 1 ]]; then
  info "🤖 Installing optional inference tools..."
  run_pipe "curl -fsSL https://ollama.ai/install.sh | sh || true"
  run_pipe "curl -fsSL https://llmfit.axjns.dev/install.sh | sh || true"
fi

# We intentionally do not install/compile pyenv Python versions here.
if command -v pyenv >/dev/null 2>&1; then
  if pyenv versions --bare | grep -Fxq "$PYVER"; then
    ok "pyenv has ${PYVER} installed."
  else
    warn "pyenv version ${PYVER} is not installed (installer does not manage pyenv versions)."
  fi
fi

# Apply user config and optional editor/prompt enhancements.
# Configure starship before skel deploy so fresh installs can use the
# official preset command path; skel merge then preserves existing config.
configure_starship_prompt
deploy_skel_profile "$SKEL_PROFILE"
configure_nano_syntax
ensure_zsh_pyenv_plugin

# ~/.python-version is managed only when CREATE_HOME_PYVER is enabled
# (via flags or inventory).
if [[ "$CREATE_HOME_PYVER" -eq 1 ]]; then
  pyver_file="${HOME}/.python-version"
  if [[ -f "$pyver_file" && "$OVERRIDE" -eq 0 ]]; then
    info "↪️  Keeping existing ${pyver_file}"
  elif [[ -f "$pyver_file" && "$OVERRIDE" -eq 1 ]]; then
    backup_path "$pyver_file"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      printf '🧪 DRY: echo %q > %q\n' "$PYVER" "$pyver_file"
    else
      printf '%s\n' "$PYVER" > "$pyver_file"
      ok "Configured ${pyver_file} (${PYVER})"
    fi
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: echo %q > %q\n' "$PYVER" "$pyver_file"
  else
    printf '%s\n' "$PYVER" > "$pyver_file"
    ok "Configured ${pyver_file} (${PYVER})"
  fi
fi

# Offer shell switch only when current shell is not zsh.
if [[ "${SHELL##*/}" != "zsh" ]] && command -v zsh >/dev/null 2>&1; then
  if [[ ! -t 0 ]]; then
    info "Non-interactive shell detected; skipping automatic 'chsh -s zsh'. Run it manually if desired."
  else
    if [[ "$ASSUME_YES" -eq 0 ]]; then
      confirm_or_die "Change default shell to zsh?"
    fi
    run chsh -s "$(command -v zsh)" || true
  fi
fi

print_checks
ok "Install script finished."
