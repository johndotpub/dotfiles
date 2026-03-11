#!/usr/bin/env bash
set -euo pipefail

# Starship prompt configuration helper.
# Called by install.sh with required env vars passed explicitly:
#   PRESERVE   - 1 to keep existing config untouched; 0 (default) backup-and-replace
#   DRY_RUN    - 1 to print actions without executing
#   VERBOSE    - 1 for debug output
#   SKEL_DIR   - path to the skel directory tree
#   SKEL_PROFILE - skel profile name (e.g. "default")

# Accept env vars from installer context with safe defaults.
PRESERVE="${PRESERVE:-0}"
DRY_RUN="${DRY_RUN:-0}"
VERBOSE="${VERBOSE:-0}"
SKEL_DIR="${SKEL_DIR:-}"
SKEL_PROFILE="${SKEL_PROFILE:-default}"

# shellcheck source=scripts/lib/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/helpers.sh"

# Prefer the official preset command when available so users get the
# canonical upstream style. Fall back to the bundled preset file otherwise.
target="${HOME}/.config/starship.toml"
fallback="${SKEL_DIR}/${SKEL_PROFILE}/.config/starship.toml"

if [[ -f "$target" && "$PRESERVE" -eq 1 ]]; then
  info "↪️  Keeping existing ${target}"
  exit 0
fi

if [[ -f "$target" ]]; then
  # Idempotency: if file already matches the fallback skel, skip backup and copy.
  if [[ -f "$fallback" ]] && diff -q "$target" "$fallback" >/dev/null 2>&1; then
    debug "Skipping ${target} (already matches skel)"
    exit 0
  fi
  backup_path "$target"
fi

run mkdir -p "${HOME}/.config"

if command -v starship >/dev/null 2>&1 && starship preset --help >/dev/null 2>&1; then
  run starship preset tokyo-night -o "$target"
  ok "Configured starship preset: tokyo-night"
  exit 0
fi

if [[ -f "$fallback" ]]; then
  run cp -Rp "$fallback" "$target"
  warn "starship preset command unavailable; applied fallback tokyo-night config."
  exit 0
fi

warn "starship config not written (no preset command and no fallback file)."
