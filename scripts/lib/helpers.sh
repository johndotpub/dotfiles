#!/usr/bin/env bash
# Shared helpers sourced by install.sh and scripts/setup-starship.sh.
# Requires: VERBOSE, DRY_RUN, DOTFILES_TEST_TIMESTAMP to be set by caller.

# ------------------------------------------------------------------------------
# Logging helpers — user-facing status messages
# ------------------------------------------------------------------------------
info()  { printf 'ℹ️  %s\n' "$*"; }
ok()    { printf '✅ %s\n' "$*"; }
warn()  { printf '⚠️  %s\n' "$*"; }
err()   { printf '❌ %s\n' "$*" >&2; }
debug() { if [[ "${VERBOSE:-0}" -eq 1 ]]; then printf '🔎 %s\n' "$*"; fi; }

# Build a shell-quoted representation of a command for dry-run/verbose output.
format_cmd() {
  local out="" arg=""
  for arg in "$@"; do out+=" $(printf '%q' "$arg")"; done
  printf '%s' "${out# }"
}

# Execute a command (or print it in dry-run mode).
run() {
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    printf '🧪 DRY: %s\n' "$(format_cmd "$@")"
    return 0
  fi
  [[ "${VERBOSE:-0}" -eq 1 ]] && printf '🔎 RUN: %s\n' "$(format_cmd "$@")"
  "$@"
}

# Return the current timestamp (frozen in tests via DOTFILES_TEST_TIMESTAMP).
timestamp() {
  if [[ -n "${DOTFILES_TEST_TIMESTAMP:-}" ]]; then
    printf '%s\n' "$DOTFILES_TEST_TIMESTAMP"
  else
    date +%Y%m%d%H%M%S
  fi
}

# Build a unique backup target path: <base>.bak.<ts>[.<n>] to avoid collisions.
next_backup_path() {
  local base="$1" ts candidate i
  ts="$(timestamp)"
  candidate="${base}.bak.${ts}"
  i=0
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    i=$((i + 1))
    candidate="${base}.bak.${ts}.${i}"
  done
  printf '%s\n' "$candidate"
}

# Move an existing path to its unique backup location.
backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local bak
    bak="$(next_backup_path "$path")"
    run mv "$path" "$bak"
    debug "Backed up ${path} -> ${bak}"
  fi
}

# Copy an existing path to a unique backup location, leaving the original in place.
backup_copy() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local bak
    bak="$(next_backup_path "$path")"
    run cp -Rp "$path" "$bak"
    debug "Backed up copy ${path} -> ${bak}"
  fi
}
