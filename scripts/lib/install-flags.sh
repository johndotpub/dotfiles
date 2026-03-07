#!/usr/bin/env bash

# Single source of truth for the flags bootstrap.sh forwards to install.sh.
# Defines build_install_args — the canonical list of forwarded flags.
#
# Usage: source this file from the extracted repo directory inside bootstrap.sh,
# then set install_args=(...) and call build_install_args before ./install.sh.

# Append all user-supplied forwarded flags to the install_args array.
# install_args must be initialized by the caller before invoking this function.
# All flag variables use ${VAR:-default} to safely read bootstrap.sh state
# under set -u without requiring re-declaration here.
build_install_args() {
  [[ -n "${HOST:-}" ]]              && install_args+=(--host "${HOST}")
  [[ -n "${PYVER:-}" ]]             && install_args+=(--pyver "${PYVER}")
  [[ "${ASSUME_YES:-0}"       -eq 1 ]] && install_args+=(-y)
  [[ "${NO_APT:-0}"           -eq 1 ]] && install_args+=(--no-apt)
  [[ "${BREW_ONLY:-0}"        -eq 1 ]] && install_args+=(--brew-only)
  [[ "${DRY_RUN:-0}"          -eq 1 ]] && install_args+=(--dry-run)
  [[ "${PRESERVE:-0}"         -eq 1 ]] && install_args+=(--preserve)
  [[ "${VERBOSE:-0}"          -eq 1 ]] && install_args+=(--verbose)
  [[ "${CREATE_HOME_PYVER:-0}" -eq 1 ]] && install_args+=(--create-home-pyver)
  [[ "${INSTALL_INFERENCE:-0}" -eq 1 ]] && install_args+=(--install-inference)
  [[ -n "${REPORT_JSON:-}" ]]       && install_args+=(--report-json "${REPORT_JSON}")
  [[ "${NO_LOCK:-0}"          -eq 1 ]] && install_args+=(--no-lock)
  # Explicit return 0 ensures the function exits cleanly under set -euo pipefail
  # even when the last flag check is false (i.e., the flag is not set).
  return 0
}
