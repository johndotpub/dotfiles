#!/usr/bin/env bash
set -euo pipefail

# Tiny bootstrap script:
# - Downloads a release tarball (or the main branch archive when --tag is omitted)
# - Verifies SHA256 checksum (release path only; skipped for main branch)
# - Optionally verifies GPG signature for the checksum file (release path only)
# - Executes install.sh from extracted archive
#
# Usage (pinned release — recommended):
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.2.3
#
# Usage (latest main branch — unverified, convenience only):
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash

REPO="johndotpub/dotfiles"

# Runtime flags forwarded to install.sh.
TAG=""
HOST=""
PYVER=""
ASSUME_YES=0
NO_APT=0
BREW_ONLY=0
DRY_RUN=0
# Optional signer pin for checksum signature verification.
# When set, verification fails unless the signature matches this fingerprint.
EXPECTED_GPG_FINGERPRINT="${BOOTSTRAP_GPG_FINGERPRINT:-}"

# Verify <artifact> against expected SHA256 listed in checksum file.
# Supports GNU coreutils (`sha256sum`) and BSD/macOS (`shasum -a 256`).
verify_checksum() {
  local checksum_file="$1"
  local artifact_file="$2"
  local artifact_name expected actual
  artifact_name="$(basename "$artifact_file")"

  # Parse checksum entries and bind the expected hash to the exact artifact name.
  expected="$(
    awk -v file="$artifact_name" '
      /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
      {
        hash = ""
        name = ""
        if ($0 ~ /^SHA256 \(/) {
          line = $0
          sub(/^SHA256 \(/, "", line)
          split(line, parts, /\) = /)
          if (length(parts) >= 2) {
            name = parts[1]
            hash = parts[2]
          }
        } else {
          hash = $1
          name = $2
          sub(/^\*/, "", name)
        }
        if (tolower(name) == tolower(file) && hash ~ /^[0-9a-fA-F]{64}$/) {
          print tolower(hash)
          exit
        }
      }
    ' "$checksum_file"
  )"

  if [[ -z "$expected" ]]; then
    echo "❌ Could not find a SHA256 entry for ${artifact_name} in ${checksum_file}."
    return 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$artifact_file" | awk '{print tolower($1)}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$artifact_file" | awk '{print tolower($1)}')"
  else
    echo "❌ No SHA256 tool found (need sha256sum or shasum)."
    return 1
  fi

  if [[ "$actual" != "$expected" ]]; then
    echo "❌ SHA256 mismatch for ${artifact_file}."
    return 1
  fi
  echo "${artifact_file}: OK"
}

# Print usage and exit with optional code.
usage() {
  local code="${1:-1}"
  cat <<EOF
Usage: bootstrap.sh [--tag <tag>] [--host <host>] [--pyver <ver>] [-y] [--no-apt] [--brew-only] [--dry-run]

  --tag <tag>  (optional) Download a specific release tag.  Omit to install
               the latest main branch directly (no checksum verification).

Examples:
  # Pinned release (recommended — checksum-verified):
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.2.3

  # Latest main branch (unverified — convenience):
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash
EOF
  exit "$code"
}

# Parse minimal bootstrap args and forward only supported installer flags.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    --pyver) PYVER="$2"; shift 2 ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --no-apt) NO_APT=1; shift ;;
    --brew-only) BREW_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1"; usage 1 ;;
  esac
done

# Build release asset URLs from owner/repo + tag.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"

# When --tag is omitted fall back to downloading the latest main branch archive.
# This path skips checksum and GPG verification because GitHub branch archives
# do not ship a .sha256 file; the user is warned before anything is executed.
if [[ -z "$TAG" ]]; then
  # Override URL for integration tests; defaults to the GitHub archive endpoint.
  MAIN_URL="${BOOTSTRAP_MAIN_URL:-https://github.com/${REPO}/archive/refs/heads/main.tar.gz}"
  ASSET_BASENAME="${REPO##*/}-main.tar.gz"

  echo "⚠️  No --tag provided: installing latest main branch (unverified)."
  echo "ℹ️  For a checksum-verified install, use: --tag v1.0.4"
  echo "📥 Downloading main branch archive..."
  curl -fsSLo "${ASSET_BASENAME}" -L "${MAIN_URL}"

  echo "📦 Extracting main branch archive..."
  mkdir -p repo
  tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
  cd repo
  chmod +x install.sh

  echo "🚀 Running installer..."
  install_args=(--from-release)
  if [[ -n "$HOST" ]]; then
    install_args+=(--host "$HOST")
  fi
  if [[ -n "$PYVER" ]]; then
    install_args+=(--pyver "$PYVER")
  fi
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    install_args+=(-y)
  fi
  if [[ "$NO_APT" -eq 1 ]]; then
    install_args+=(--no-apt)
  fi
  if [[ "$BREW_ONLY" -eq 1 ]]; then
    install_args+=(--brew-only)
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    install_args+=(--dry-run)
  fi

  ./install.sh "${install_args[@]}"
  echo "✅ Bootstrap complete."
  exit 0
fi

# Tagged release path: full download + SHA256 + optional GPG verification.
RELEASE_BASE="https://github.com/${REPO}/releases/download/${TAG}"
# Test/advanced override for integration environments that need bootstrap to
# fetch artifacts from a non-GitHub release base URL.
if [[ -n "${BOOTSTRAP_RELEASE_BASE:-}" ]]; then
  RELEASE_BASE="${BOOTSTRAP_RELEASE_BASE}"
fi
ASSET_BASENAME="${REPO##*/}-${TAG}.tar.gz"
TARBALL_URL="${RELEASE_BASE}/${ASSET_BASENAME}"

echo "📥 Downloading release tarball..."
curl -fsSLo "${ASSET_BASENAME}" -L "${TARBALL_URL}"

SHA_URL="${TARBALL_URL}.sha256"
SHA_SIG_URL="${SHA_URL}.asc"
echo "📥 Downloaded: ${ASSET_BASENAME}"

echo "📥 Downloading checksum..."
curl -fsSLo "${ASSET_BASENAME}.sha256" -L "${SHA_URL}"

# Optional GPG verification for checksum file
# If a detached signature is published for the checksum, verify it.
if curl -fsSLo /dev/null -L "${SHA_SIG_URL}" 2>/dev/null; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "ℹ️ Skipping GPG verification: 'gpg' is not installed."
  else
    gpg_status=""
    signer_fpr=""
    expected_fpr=""
    echo "🔐 Found checksum signature; verifying with gpg..."
    curl -fsSLo "${ASSET_BASENAME}.sha256.asc" -L "${SHA_SIG_URL}"
    if ! gpg_status="$(gpg --status-fd=1 --verify "${ASSET_BASENAME}.sha256.asc" "${ASSET_BASENAME}.sha256" 2>&1)"; then
      echo "❌ GPG verification failed; aborting."
      exit 2
    fi
    signer_fpr="$(printf '%s\n' "$gpg_status" | awk '/^\[GNUPG:\] VALIDSIG / {print toupper($3); exit}')"
    if [[ -n "$EXPECTED_GPG_FINGERPRINT" ]]; then
      expected_fpr="$(printf '%s' "$EXPECTED_GPG_FINGERPRINT" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
      if [[ -z "$signer_fpr" || "$signer_fpr" != "$expected_fpr" ]]; then
        echo "❌ GPG signer fingerprint mismatch."
        echo "Expected: ${expected_fpr}"
        echo "Actual:   ${signer_fpr:-<unknown>}"
        exit 2
      fi
      echo "✅ GPG signature verified with expected fingerprint: ${expected_fpr}"
    else
      echo "ℹ️ GPG signature verified."
      echo "ℹ️ Tip: set BOOTSTRAP_GPG_FINGERPRINT to enforce a specific trusted signer."
    fi
  fi
fi

echo "🧾 Verifying checksum..."
# This validates the tarball bytes before we execute anything from it.
verify_checksum "${ASSET_BASENAME}.sha256" "${ASSET_BASENAME}"

echo "📦 Extracting release..."
mkdir -p repo
tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
cd repo
# Ensure installer is executable in freshly extracted archives.
chmod +x install.sh

echo "🚀 Running installer..."
# Construct args array safely to avoid quoting bugs.
install_args=(--from-release --tag "$TAG")
if [[ -n "$HOST" ]]; then
  install_args+=(--host "$HOST")
fi
if [[ -n "$PYVER" ]]; then
  install_args+=(--pyver "$PYVER")
fi
if [[ "$ASSUME_YES" -eq 1 ]]; then
  install_args+=(-y)
fi
if [[ "$NO_APT" -eq 1 ]]; then
  install_args+=(--no-apt)
fi
if [[ "$BREW_ONLY" -eq 1 ]]; then
  install_args+=(--brew-only)
fi
if [[ "$DRY_RUN" -eq 1 ]]; then
  install_args+=(--dry-run)
fi

# Execute installer from the verified release payload.
./install.sh "${install_args[@]}"
echo "✅ Bootstrap complete."
