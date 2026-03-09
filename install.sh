#!/usr/bin/env bash
set -euo pipefail

# Brew-first, idempotent installer for dotfiles.
# Usage: ./install.sh [--ref REF] [--host HOST] [--pyver 3.12.12] [--create-home-pyver] [--dry-run] [--preserve] [--brew-only] [--no-apt] [--verbose] [-y]
#
# High-level flow:
#   1) Parse CLI flags and resolve effective config (CLI + inventory)
#   2) Prepare base dependencies (optional apt + brew bootstrap)
#   3) Install package sets (brew first, apt fallback)
#   4) Apply user-facing config (skel files, starship, nano syntax)
#   5) Run post-install checks and exit with clear status logs

# Default deploy behaviour: backup existing files to .bak.<date> and deploy
# fresh copies from skel.  Pass --preserve to keep existing files untouched.
PRESERVE=0
CREATE_HOME_PYVER=0
PYVER="3.12.12"
NO_APT=0
BREW_ONLY=0
DRY_RUN=0
ASSUME_YES=0
VERBOSE=0
HOST=""
REF=""
FROM_RELEASE=0
REPORT_JSON=""
NO_LOCK=0

LOCK_DIR=""
LOCK_HELD=0

PHASE_LOCK="pending"
PHASE_PREFLIGHT="pending"
PHASE_APT_BASELINE="pending"
PHASE_BREW_BOOTSTRAP="pending"
PHASE_BREW_PACKAGES="pending"
PHASE_APT_FALLBACK="pending"
PHASE_CONFIG="pending"
PHASE_CHECKS="pending"

# Track whether the user explicitly set values so inventory can provide defaults.
CLI_SET_PYVER=0
CLI_SET_CREATE_HOME_PYVER=0

# Optional package section overrides loaded from inventory files.
# - brew: empty means "install every section in packages/brew.yaml"
# - apt:  empty means "install no optional sections from packages/apt.yaml"
BREW_SECTIONS=()
APT_SECTIONS=()

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKEL_DIR="${REPO_DIR}/skel"
PKG_DIR="${REPO_DIR}/packages"
INVENTORY_DIR="${REPO_DIR}/inventory"
SKEL_PROFILE="default"
# shellcheck source=scripts/lib/brew-env.sh
source "${REPO_DIR}/scripts/lib/brew-env.sh"

timestamp() {
  if [[ -n "${DOTFILES_TEST_TIMESTAMP:-}" ]]; then
    printf '%s\n' "$DOTFILES_TEST_TIMESTAMP"
  else
    date +%Y%m%d%H%M%S
  fi
}

# Build a unique backup target path using timestamp + numeric suffix.
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

# Execute a command (or print it in dry-run mode).
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: %s\n' "$(format_cmd "$@")"
    return 0
  fi
  [[ "$VERBOSE" -eq 1 ]] && printf '🔎 RUN: %s\n' "$(format_cmd "$@")"
  "$@"
}

# Execute a pipeline string (kept for legacy install snippets).
run_pipe() {
  local pipeline="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: %s\n' "$pipeline"
    return 0
  fi
  [[ "$VERBOSE" -eq 1 ]] && printf '🔎 RUN: %s\n' "$pipeline"
  bash -c "$pipeline"
}

# Print CLI help text.
usage() {
  cat <<EOF
install.sh [options]
Options:
  -h, --help                 Show this help
      --preserve             Keep existing files untouched (opt out of backup-and-replace)
      --create-home-pyver    Create ~/.python-version with --pyver value
      --pyver <ver>          Python version for ~/.python-version (default: ${PYVER})
      --no-apt               Skip apt installs
      --brew-only            Prefer brew only; skip apt fallback
      --dry-run              Print actions without executing
  -y, --yes                  Assume yes for prompts
      --verbose              Verbose logging
      --host <host>          Optional inventory overlay: inventory/hosts/<host>.yaml
      --ref <ref>            Release tag, branch, or commit SHA (informational)
      --from-release         Informational flag set by bootstrap
      --report-json <path>   Write final install report JSON to path
      --no-lock              Disable installer lock (advanced/debug)
      --skel-dir <path>      Use alternate skel directory
      --packages-dir <path>  Use alternate packages directory
      --inventory-dir <path> Use alternate inventory directory

Behavior:
  - Existing files are backed up to .bak.<date> and replaced with fresh skel copies.
  - If a deployed file already matches skel exactly, the backup and copy are skipped.
  - Use --preserve to keep existing files untouched (no backups, no replacement).
EOF
}

# Manual argument parsing keeps behavior portable across GNU/Linux, WSL, and macOS.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --preserve)
      PRESERVE=1
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
    --ref)
      [[ $# -ge 2 ]] || { err "--ref requires a value"; exit 1; }
      REF="$2"
      shift 2
      ;;
    --from-release)
      FROM_RELEASE=1
      shift
      ;;
    --report-json)
      [[ $# -ge 2 ]] || { err "--report-json requires a value"; exit 1; }
      REPORT_JSON="$2"
      shift 2
      ;;
    --no-lock)
      NO_LOCK=1
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
debug "ref=${REF:-<none>}"
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

# Escape string data for JSON output fields.
json_escape() {
  local s="$1"
  local out="" code hex char
  while IFS= read -r code; do
    [[ -n "$code" ]] || continue
    if (( code == 34 )); then
      out+="\\\""
    elif (( code == 92 )); then
      out+="\\\\"
    elif (( code == 8 )); then
      out+="\\b"
    elif (( code == 9 )); then
      out+="\\t"
    elif (( code == 10 )); then
      out+="\\n"
    elif (( code == 12 )); then
      out+="\\f"
    elif (( code == 13 )); then
      out+="\\r"
    elif (( code >= 0 && code <= 31 )); then
      printf -v hex '%04x' "$code"
      out+="\\u${hex}"
    else
      printf -v char '%b' "\\$(printf '%03o' "$code")"
      out+="$char"
    fi
  done < <(printf '%s' "$s" | od -An -t u1 -v | tr -s '[:space:]' '\n')
  printf '%s' "$out"
}

# Emit end-of-run phase summary and optional JSON report.
write_install_report() {
  local exit_code="$1"
  local final_status="error"
  if [[ "$exit_code" -eq 0 ]]; then
    final_status="success"
  fi

  info "📋 Install phase summary: lock=${PHASE_LOCK}, preflight=${PHASE_PREFLIGHT}, apt_baseline=${PHASE_APT_BASELINE}, brew_bootstrap=${PHASE_BREW_BOOTSTRAP}, brew_packages=${PHASE_BREW_PACKAGES}, apt_fallback=${PHASE_APT_FALLBACK}, config=${PHASE_CONFIG}, checks=${PHASE_CHECKS}"

  if [[ -z "$REPORT_JSON" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: would write install report to %s\n' "$REPORT_JSON"
    return 0
  fi

  run mkdir -p "$(dirname "$REPORT_JSON")"
  cat > "$REPORT_JSON" <<EOF
{
  "status": "$(json_escape "$final_status")",
  "exit_code": ${exit_code},
  "ref": "$(json_escape "${REF:-}")",
  "host": "$(json_escape "${HOST:-}")",
  "from_release": ${FROM_RELEASE},
  "dry_run": ${DRY_RUN},
  "preserve": ${PRESERVE},
  "phase": {
    "lock": "$(json_escape "$PHASE_LOCK")",
    "preflight": "$(json_escape "$PHASE_PREFLIGHT")",
    "apt_baseline": "$(json_escape "$PHASE_APT_BASELINE")",
    "brew_bootstrap": "$(json_escape "$PHASE_BREW_BOOTSTRAP")",
    "brew_packages": "$(json_escape "$PHASE_BREW_PACKAGES")",
    "apt_fallback": "$(json_escape "$PHASE_APT_FALLBACK")",
    "config": "$(json_escape "$PHASE_CONFIG")",
    "checks": "$(json_escape "$PHASE_CHECKS")"
  }
}
EOF
  ok "Wrote install report: ${REPORT_JSON}"
}

# Acquire a process lock so two installers do not mutate dotfiles concurrently.
acquire_install_lock() {
  # Dry-run must be side-effect free; skip lock file mutations.
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "🧪 DRY: skipping installer lock acquisition."
    PHASE_LOCK="skipped"
    return 0
  fi

  if [[ "$NO_LOCK" -eq 1 ]]; then
    info "🔓 Installer lock disabled (--no-lock)."
    PHASE_LOCK="disabled"
    return 0
  fi

  LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-install.${UID}.lock"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_HELD=1
    printf '%s\n' "$$" > "${LOCK_DIR}/pid"
    PHASE_LOCK="ok"
    return 0
  fi

  local holder_pid=""
  if [[ -f "${LOCK_DIR}/pid" ]]; then
    holder_pid="$(awk 'NR==1 {print $1}' "${LOCK_DIR}/pid" 2>/dev/null || true)"
  fi

  if [[ -n "$holder_pid" ]] && kill -0 "$holder_pid" 2>/dev/null; then
    PHASE_LOCK="blocked"
    err "Another installer process is already running (pid ${holder_pid})."
    err "Wait for it to finish, or use --no-lock only if you know installs won't overlap."
    exit 1
  fi

  warn "Recovered stale installer lock at ${LOCK_DIR}."
  rm -rf "$LOCK_DIR"
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_HELD=1
    printf '%s\n' "$$" > "${LOCK_DIR}/pid"
    PHASE_LOCK="ok"
    return 0
  fi

  PHASE_LOCK="error"
  err "Could not acquire installer lock: ${LOCK_DIR}"
  exit 1
}

# Best-effort lock cleanup on exit.
release_install_lock() {
  if [[ "$LOCK_HELD" -eq 1 && -n "$LOCK_DIR" && -d "$LOCK_DIR" ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

# Validate core runtime tooling before making changes.
run_preflight_checks() {
  PHASE_PREFLIGHT="in_progress"
  info "🧪 Running preflight checks..."

  local missing=0
  local required_tools=(bash awk cp mv tar)
  local tool=""
  for tool in "${required_tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      debug "preflight: ${tool}=ok"
    else
      err "Missing required tool: ${tool}"
      missing=1
    fi
  done

  if command -v curl >/dev/null 2>&1; then
    debug "preflight: curl=ok"
  else
    warn "curl not found yet (installer will attempt apt fallback where allowed)."
  fi

  if command -v brew >/dev/null 2>&1 || [[ -x "/opt/homebrew/bin/brew" || -x "/usr/local/bin/brew" ]]; then
    debug "preflight: brew probe=ok"
  else
    warn "Homebrew not found yet (installer will bootstrap it)."
  fi

  if [[ "$missing" -eq 1 ]]; then
    PHASE_PREFLIGHT="error"
    err "Preflight checks failed."
    exit 1
  fi

  PHASE_PREFLIGHT="ok"
}

# Interactive confirmation helper used for shell switch prompts.
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

# Parse common boolean-like YAML values into 0/1 toggles.
bool_to_int() {
  local normalized
  normalized="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  case "$normalized" in
    true|yes|y|on|1) printf '1' ;;
    false|no|n|off|0) printf '0' ;;
    *) printf '%s' "$2" ;;
  esac
}

# Minimal scalar lookup from simple inventory YAML files.
yaml_get_scalar() {
  local key="$1"
  local file="$2"
  awk -F': *' -v k="$key" '$1 == k {print $2; exit}' "$file" | tr -d "\"'"
}

# Check whether a top-level YAML list key exists in a simple inventory file.
yaml_has_list_key() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*$" { found = 1; exit }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

# Read a simple top-level YAML list from an inventory file.
yaml_get_list() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '
    BEGIN { in_list = 0 }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*$" { in_list = 1; next }
    in_list && $0 ~ "^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$" { in_list = 0 }
    in_list && $0 ~ "^[[:space:]]*-[[:space:]]+" {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "$file"
}

# Apply inventory defaults unless user supplied explicit CLI values.
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
  val="$(yaml_get_scalar "skel_profile" "$file" || true)"
  [[ -n "$val" ]] && SKEL_PROFILE="$val"
  if yaml_has_list_key "brew_sections" "$file"; then
    BREW_SECTIONS=()
    while IFS= read -r val; do
      [[ -n "$val" ]] || continue
      BREW_SECTIONS+=("$val")
    done < <(yaml_get_list "brew_sections" "$file")
  fi
  if yaml_has_list_key "apt_sections" "$file"; then
    APT_SECTIONS=()
    while IFS= read -r val; do
      [[ -n "$val" ]] || continue
      APT_SECTIONS+=("$val")
    done < <(yaml_get_list "apt_sections" "$file")
  fi
}

# Read a YAML list section using a strict, lightweight awk parser.
read_yaml_list() {
  local file="$1"
  local section="$2"
  awk -v section="$section" '
    BEGIN { in_section = 0 }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" { in_section = 1; next }
    in_section && $0 ~ "^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$" { in_section = 0 }
    in_section && $0 ~ "^[[:space:]]*-[[:space:]]+" {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+/, "", line)
      sub(/[[:space:]]+#.*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line != "") print line
    }
  ' "$file"
}

# List the top-level package sections available in a package inventory file.
list_yaml_sections() {
  local file="$1"
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^[[:space:]]*[a-zA-Z0-9_-]+:[[:space:]]*$/ {
      line = $0
      sub(/:[[:space:]]*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
    }
  ' "$file"
}

# Return success when the candidate already exists in the provided list.
array_contains() {
  local needle="$1"
  shift || true
  local item=""
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

# Resolve the effective package sections for a package manager inventory file.
# Default behavior is intentionally asymmetric:
# - brew installs every section when no override is configured
# - apt installs no optional sections unless inventory opts into them
resolve_package_sections() {
  local file="$1"
  local default_mode="$2"
  shift 2
  local requested_sections=("$@")
  local section=""

  if [[ "${#requested_sections[@]}" -gt 0 ]]; then
    printf '%s\n' "${requested_sections[@]}"
    return 0
  fi

  if [[ "$default_mode" != "all" ]]; then
    return 0
  fi

  while IFS= read -r section; do
    [[ -n "$section" ]] || continue
    printf '%s\n' "$section"
  done < <(list_yaml_sections "$file")
}

# Collect and de-duplicate package names from the requested YAML sections.
collect_yaml_packages() {
  local file="$1"
  shift
  local sections=("$@")
  local pkgs=()
  local section=""
  local pkg=""

  for section in "${sections[@]}"; do
    while IFS= read -r pkg; do
      [[ -n "$pkg" ]] || continue
      if ! array_contains "$pkg" "${pkgs[@]}"; then
        pkgs+=("$pkg")
      fi
    done < <(read_yaml_list "$file" "$section")
  done

  for pkg in "${pkgs[@]}"; do
    printf '%s\n' "$pkg"
  done
}

# Install a de-duplicated package set from one or more YAML sections.
install_packages_from_yaml() {
  local manager="$1"
  local file="$2"
  local default_mode="$3"
  shift 3
  [[ -f "$file" ]] || return 0

  local sections=()
  local pkgs=()
  local value=""

  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    sections+=("$value")
  done < <(resolve_package_sections "$file" "$default_mode" "$@")

  while IFS= read -r value; do
    [[ -n "$value" ]] || continue
    pkgs+=("$value")
  done < <(collect_yaml_packages "$file" "${sections[@]}")

  if [[ "${#pkgs[@]}" -eq 0 ]]; then
    debug "No ${manager} packages selected from ${file}"
    return 0
  fi

  if [[ "$manager" == "brew" ]]; then
    info "🍺 Installing brew packages..."
    if ! run brew install "${pkgs[@]}"; then
      warn "brew install failed for one or more packages listed in ${file}. Review output and retry."
      return 1
    fi
    return 0
  fi

  info "📦 Installing optional apt packages..."
  if ! run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"; then
    warn "apt package installation failed for one or more packages listed in ${file}."
    return 1
  fi
}

# Rename target to a unique backup path (used for override mode).
backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local bak
    bak="$(next_backup_path "$path")"
    run mv "$path" "$bak"
    debug "Backed up ${path} -> ${bak}"
  fi
}

# Copy target to a unique backup path while keeping original in place.
backup_copy() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local bak
    bak="$(next_backup_path "$path")"
    run cp -Rp "$path" "$bak"
    debug "Backed up copy ${path} -> ${bak}"
  fi
}

# Portable recursive copy wrapper used by skel deployment.
copy_item() {
  local src="$1"
  local dest="$2"
  run cp -Rp "$src" "$dest"
}

# Merge src directory into dest without overwriting existing files.
merge_dir_without_overwrite() {
  local src="$1"
  local dest="$2"
  if command -v rsync >/dev/null 2>&1; then
    run rsync -a --ignore-existing "${src}/" "${dest}/"
  else
    local item rel target
    run mkdir -p "$dest"
    while IFS= read -r -d '' item; do
      rel="${item#"${src}"/}"
      target="${dest}/${rel}"
      if [[ -e "$target" || -L "$target" ]]; then
        continue
      fi
      run mkdir -p "$(dirname "$target")"
      run cp -Rp "$item" "$target"
    done < <(find "$src" -mindepth 1 -print0)
  fi
}

install_brew_if_missing() {
  # Reuse shared helper so brew path resolution stays centralized.
  if setup_brew_env; then
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
  setup_brew_env || {
    err "Failed to initialize Homebrew after install."
    exit 1
  }
  ok "Homebrew installed and initialized."
}

# Install baseline apt packages needed on Linux before brew workloads.
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

# Install optional apt package sections from packages/apt.yaml.
install_apt_from_yaml() {
  local file="$1"
  shift
  [[ -f "$file" ]] || return 0
  if ! command -v apt-get >/dev/null 2>&1; then
    debug "apt-get not found; skipping apt fallback installs"
    return 0
  fi
  install_packages_from_yaml "apt" "$file" "none" "$@"
}

# Install brew package sections from packages/brew.yaml.
install_brew_from_yaml() {
  local file="$1"
  shift
  [[ -f "$file" ]] || return 0
  install_packages_from_yaml "brew" "$file" "all" "$@"
}

deploy_skel_profile() {
  # Deploy policy:
  # - default (PRESERVE=0): backup existing files to .bak.<timestamp>, deploy fresh skel copy.
  #   Idempotent: if the destination already matches skel exactly, skip backup and copy.
  # - --preserve (PRESERVE=1): keep existing files untouched; only fill missing content.
  # Directories are always merged without overwriting existing files, regardless of PRESERVE.
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
      if [[ -d "$src" && -d "$dest" ]]; then
        # Directories: always merge without overwriting existing files.
        info "↪️  Keeping existing ${dest} (adding missing files only)"
        merge_dir_without_overwrite "$src" "$dest"
      elif [[ "$PRESERVE" -eq 1 ]]; then
        # --preserve: keep existing file unchanged.
        info "↪️  Keeping existing ${dest}"
      elif diff -q "$src" "$dest" >/dev/null 2>&1; then
        # Content already matches skel: idempotent skip, no spurious backup.
        debug "Skipping ${dest} (already matches skel)"
      else
        # Default: backup existing file then deploy fresh skel copy.
        backup_path "$dest"
        copy_item "$src" "$dest"
        debug "Processed ${dest}"
      fi
      continue
    fi
    copy_item "$src" "$dest"
    debug "Processed ${dest}"
  done
  shopt -u dotglob nullglob
}


configure_oh_my_tmux() {
  # oh-my-tmux provides sane tmux defaults while ~/.tmux.conf.local remains
  # the user-customizable override file that we ship via skel/default.
  local tmux_dir="${HOME}/.tmux"
  local tmux_conf="${HOME}/.tmux.conf"
  local tmux_repo="https://github.com/gpakosz/.tmux.git"
  local tmux_main_conf="${tmux_dir}/.tmux.conf"

  info "🧱 Ensuring oh-my-tmux configuration..."

  if [[ ! -d "$tmux_dir" ]]; then
    if ! run git clone --depth 1 "$tmux_repo" "$tmux_dir"; then
      warn "Could not clone oh-my-tmux; keeping existing tmux setup."
      return 1
    fi
  else
    info "↪️  Keeping existing ${tmux_dir}"
  fi

  if [[ ! -f "$tmux_main_conf" ]]; then
    warn "oh-my-tmux clone is missing ${tmux_main_conf}; skipping tmux.conf symlink."
    return 1
  fi

  if [[ -e "$tmux_conf" || -L "$tmux_conf" ]]; then
    if [[ "$PRESERVE" -eq 1 ]]; then
      # --preserve: keep existing tmux.conf unchanged.
      info "↪️  Keeping existing ${tmux_conf}"
      return 0
    fi
    # Idempotency: if .tmux.conf is already the correct symlink, skip backup.
    if [[ -L "$tmux_conf" ]] && [[ "$(readlink "$tmux_conf")" == "$tmux_main_conf" ]]; then
      debug "Skipping ${tmux_conf} (already linked to ${tmux_main_conf})"
      return 0
    fi
    # Default: backup and re-link.
    backup_path "$tmux_conf"
    run ln -s "$tmux_main_conf" "$tmux_conf"
    ok "Linked ${tmux_conf} -> ${tmux_main_conf}"
    return 0
  fi

  # Fresh installs receive the oh-my-tmux primary config symlink automatically.
  run ln -s "$tmux_main_conf" "$tmux_conf"
  ok "Linked ${tmux_conf} -> ${tmux_main_conf}"
}

migrate_ssh_config_include_local() {
  # Migration behavior for existing user SSH config:
  # - if ~/.ssh/config exists, create a sanitized copy as ~/.ssh/config.local and
  #   then remove the original ~/.ssh/config before seeding the managed include wrapper.
  # - if ~/.ssh/config.local already exists, back it up before writing migrated content.
  # - self-referencing include lines are sanitized from migrated content to prevent
  #   recursive Include loops on rerun.
  local ssh_dir="${HOME}/.ssh"
  local ssh_cfg="${ssh_dir}/config"
  local ssh_local_cfg="${ssh_dir}/config.local"
  local skel_cfg="${SKEL_DIR}/${SKEL_PROFILE}/.ssh/config"

  if [[ "$PRESERVE" -eq 1 ]]; then
    debug "Preserve mode enabled; skipping SSH config include migration helper."
    return 0
  fi

  if [[ ! -e "$ssh_cfg" && ! -L "$ssh_cfg" ]]; then
    return 0
  fi

  # Idempotency guard: skip when config.local already exists AND config already
  # contains the Include directive, which means a prior migration completed.
  if [[ (-e "$ssh_local_cfg" || -L "$ssh_local_cfg") ]] \
      && grep -qF 'Include ~/.ssh/config.local' "$ssh_cfg" 2>/dev/null; then
    debug "SSH config migration already complete (include wrapper + config.local present); skipping."
    return 0
  fi

  info "🔐 Migrating existing ~/.ssh/config -> ~/.ssh/config.local"

  # Back up any pre-existing config.local before overwriting it.
  if [[ -e "$ssh_local_cfg" || -L "$ssh_local_cfg" ]]; then
    backup_path "$ssh_local_cfg"
  fi

  # Sanitize self-referencing include lines to prevent recursive Include loops
  # in config.local when config previously already contained an Include directive.
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: migrate %q -> %q (sanitized)\n' "$ssh_cfg" "$ssh_local_cfg"
  else
    local migrated_content
    # Use || true so that when grep excludes every line (empty result under
    # set -eo pipefail) the command substitution succeeds rather than aborting.
    migrated_content="$(
      grep -vF '# Load user-specific hosts/overrides from local-only file.' "$ssh_cfg" \
        | grep -vF 'Include ~/.ssh/config.local' \
        || true
    )"
    # Only create config.local when there is meaningful content to migrate.
    # Check against all whitespace (spaces, newlines, tabs) not just spaces.
    if [[ "$migrated_content" =~ [^[:space:]] ]]; then
      printf '%s\n' "$migrated_content" > "$ssh_local_cfg"
      run chmod 600 "$ssh_local_cfg"
    else
      debug "No meaningful content in ${ssh_cfg} after sanitization; skipping config.local creation."
    fi
    run rm -f "$ssh_cfg"
  fi

  # Seed managed include config so existing user hosts still load via config.local.
  if [[ -f "$skel_cfg" ]]; then
    run mkdir -p "$ssh_dir"
    copy_item "$skel_cfg" "$ssh_cfg"
    ok "Seeded managed ~/.ssh/config include wrapper."
  else
    warn "Missing skel SSH config at ${skel_cfg}; ~/.ssh/config was not re-seeded."
  fi
}

configure_nano_syntax() {
  # nanorc setup is intentionally conservative:
  # - existing ~/.nanorc is left untouched by default
  # - override mode appends include after creating a backup copy
  local nano_dir="${HOME}/.nano"
  local nano_rc="${HOME}/.nanorc"
  local include_line='include ~/.nano/*.nanorc'
  local nanorc_repo="https://github.com/scopatz/nanorc.git"
  # Pin to a known-good commit for repeatable, less-risky installs.
  local nanorc_ref="${NANORC_REF:-1aa64a86cf4c750e4d4788ef1a19d7a71ab641dd}"
  local cloned=0

  info "📝 Ensuring nano syntax highlighting..."
  if [[ ! -d "$nano_dir" ]]; then
    if run git clone --depth 1 "$nanorc_repo" "$nano_dir"; then
      cloned=1
    else
      warn "Could not clone nanorc repository; skipping nano syntax setup."
      return 0
    fi
  else
    info "↪️  Keeping existing ${nano_dir}"
  fi

  if [[ "$cloned" -eq 1 && -d "$nano_dir" ]]; then
    if ! run git -C "$nano_dir" fetch --depth 1 origin "$nanorc_ref"; then
      warn "Could not fetch pinned nanorc ref ${nanorc_ref}; continuing with cloned default branch."
    elif ! run git -C "$nano_dir" checkout --detach "$nanorc_ref"; then
      warn "Could not checkout pinned nanorc ref ${nanorc_ref}; continuing with cloned default branch."
    fi
  fi

  if [[ -d "$nano_dir" ]]; then
    run make -C "$nano_dir" install || true
  fi

  if [[ -f "$nano_rc" ]]; then
    if grep -Fxq "$include_line" "$nano_rc"; then
      debug "${nano_rc} already includes nanorc syntax files."
      return 0
    fi
    if [[ "$PRESERVE" -eq 1 ]]; then
      # --preserve: keep existing nanorc unchanged.
      info "↪️  Keeping existing ${nano_rc} (use default mode to append nanorc include)"
    else
      # Default: backup copy + append include line.
      backup_copy "$nano_rc"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '🧪 DRY: printf %q >> %q\n' "${include_line}\n" "$nano_rc"
      else
        printf '\n%s\n' "$include_line" >> "$nano_rc"
      fi
      ok "Updated ${nano_rc} to include nanorc syntax files."
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

on_exit() {
  local exit_code="$?"
  # Kill the sudo keepalive background process when the script exits.
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
  write_install_report "$exit_code" || true
  release_install_lock || true
}

trap on_exit EXIT

# Warm up sudo credentials once early so interactive prompts happen up front,
# and spawn a background keepalive loop to prevent sudo from expiring mid-run.
# This avoids password piping or storing credentials in variables.
# Only gate on apt-enabled (non-brew-only) flows to avoid unnecessary prompts
# in --no-apt or --brew-only runs; warmup is best-effort so auth failure is
# non-fatal (the keepalive loop is simply not started).
if [[ -n "$SUDO_BIN" && "$DRY_RUN" -eq 0 && "$NO_APT" -eq 0 ]]; then
  if "$SUDO_BIN" -v; then
    # Refresh sudo timestamp roughly every 50 seconds in the background for script lifetime.
    # Use sleep (not read) so the loop does not spin on closed stdin in curl|bash pipes.
    ( while true; do "$SUDO_BIN" -n true 2>/dev/null; sleep 50; done ) &
    SUDO_KEEPALIVE_PID=$!
  fi
fi

info "🚀 Starting dotfiles install..."
acquire_install_lock
run_preflight_checks
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
debug "effective_skel_profile=${SKEL_PROFILE}"

# Optional apt path for Linux hosts. Disabled in brew-only or no-apt modes.
if [[ "$NO_APT" -eq 0 && "$BREW_ONLY" -eq 0 ]]; then
  PHASE_APT_BASELINE="in_progress"
  install_apt_baseline
  if command -v locale-gen >/dev/null 2>&1; then
    run_root locale-gen en_US.UTF-8 || true
  fi
  if command -v update-locale >/dev/null 2>&1; then
    run_root update-locale LANG=en_US.UTF-8 || true
  fi
  PHASE_APT_BASELINE="ok"
else
  debug "Skipping apt baseline installs"
  PHASE_APT_BASELINE="skipped"
fi

PHASE_BREW_BOOTSTRAP="in_progress"
install_brew_if_missing
PHASE_BREW_BOOTSTRAP="ok"

BREW_YAML_FILE="${PKG_DIR}/brew.yaml"
APT_YAML_FILE="${PKG_DIR}/apt.yaml"
if [[ ! -f "$BREW_YAML_FILE" ]]; then
  err "Missing brew package inventory: ${BREW_YAML_FILE}"
  exit 1
fi

# Install the brew inventory. By default every brew section is installed.
if [[ -f "$BREW_YAML_FILE" ]]; then
  PHASE_BREW_PACKAGES="in_progress"
  install_brew_from_yaml "$BREW_YAML_FILE" "${BREW_SECTIONS[@]}"
  PHASE_BREW_PACKAGES="ok"
else
  PHASE_BREW_PACKAGES="skipped"
fi

if [[ "$BREW_ONLY" -eq 0 && "$NO_APT" -eq 0 ]]; then
  if [[ -f "$APT_YAML_FILE" ]]; then
    PHASE_APT_FALLBACK="in_progress"
    if install_apt_from_yaml "$APT_YAML_FILE" "${APT_SECTIONS[@]}"; then
      PHASE_APT_FALLBACK="ok"
    else
      PHASE_APT_FALLBACK="warn"
      warn "Optional apt package installation reported errors; continuing with brew-first flow."
    fi
  else
    PHASE_APT_FALLBACK="skipped"
  fi
else
  PHASE_APT_FALLBACK="skipped"
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
PHASE_CONFIG="in_progress"
# Delegate starship configuration to the dedicated helper script.
PRESERVE=$PRESERVE DRY_RUN=$DRY_RUN VERBOSE=$VERBOSE SKEL_DIR=$SKEL_DIR SKEL_PROFILE=$SKEL_PROFILE \
  bash "${REPO_DIR}/scripts/setup-starship.sh"
configure_oh_my_tmux || true
migrate_ssh_config_include_local
deploy_skel_profile "$SKEL_PROFILE"
configure_nano_syntax

# ~/.python-version is managed only when CREATE_HOME_PYVER is enabled
# (via flags or inventory).
if [[ "$CREATE_HOME_PYVER" -eq 1 ]]; then
  pyver_file="${HOME}/.python-version"
  if [[ -f "$pyver_file" && "$PRESERVE" -eq 1 ]]; then
    info "↪️  Keeping existing ${pyver_file}"
  elif [[ -f "$pyver_file" ]]; then
    # Default: backup and replace (unless content already matches).
    if grep -Fxq "$PYVER" "$pyver_file" 2>/dev/null; then
      debug "Skipping ${pyver_file} (already contains ${PYVER})"
    else
      backup_path "$pyver_file"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '🧪 DRY: echo %q > %q\n' "$PYVER" "$pyver_file"
      else
        printf '%s\n' "$PYVER" > "$pyver_file"
        ok "Configured ${pyver_file} (${PYVER})"
      fi
    fi
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: echo %q > %q\n' "$PYVER" "$pyver_file"
  else
    printf '%s\n' "$PYVER" > "$pyver_file"
    ok "Configured ${pyver_file} (${PYVER})"
  fi
fi

PHASE_CONFIG="ok"

PHASE_CHECKS="in_progress"
# Delegate post-install checks to the dedicated helper script.
VERBOSE=$VERBOSE bash "${REPO_DIR}/scripts/post-install-checks.sh"
PHASE_CHECKS="ok"

# Offer shell switch only when current shell is not zsh.
# Placed after print_checks so any warning about chsh appears near the end of the output,
# just before the final summary line.
if [[ "${SHELL##*/}" != "zsh" ]] && command -v zsh >/dev/null 2>&1; then
  zsh_bin="$(command -v zsh)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '🧪 DRY: ensure %q in /etc/shells\n' "$zsh_bin"
    printf '🧪 DRY: chsh -s %q\n' "$zsh_bin"
  else
    # Register the resolved zsh path in /etc/shells when missing so chsh accepts it.
    # This is required when using the Homebrew-installed zsh on Linux.
    # Use sudo -n (non-interactive) so this remains non-fatal in unattended/no-sudo runs,
    # and use $SUDO_BIN to stay consistent with the rest of the script.
    if [[ -n "$SUDO_BIN" ]] && ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
      if "$SUDO_BIN" -n true 2>/dev/null && printf '%s\n' "$zsh_bin" | "$SUDO_BIN" -n tee -a /etc/shells >/dev/null; then
        ok "Registered ${zsh_bin} in /etc/shells."
      else
        warn "Could not register ${zsh_bin} in /etc/shells; chsh may fail."
      fi
    fi

    if [[ ! -t 0 ]] || [[ "$ASSUME_YES" -eq 1 ]]; then
      # Non-interactive bootstrap installs should still converge to zsh-first
      # behavior without requiring manual post-install prompts.
      if chsh -s "$zsh_bin" "$(id -un)" </dev/null >/dev/null 2>&1; then
        ok "Updated default shell to zsh (${zsh_bin})."
      else
        warn "Could not auto-set default shell to zsh. Run: chsh -s ${zsh_bin}"
      fi
    else
      confirm_or_die "Change default shell to zsh?"
      if run chsh -s "$zsh_bin"; then
        ok "Updated default shell to zsh (${zsh_bin})."
      else
        warn "Could not set default shell to zsh automatically. Run: chsh -s ${zsh_bin}"
      fi
    fi
  fi
fi
ok "Install script finished."
