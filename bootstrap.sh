#!/usr/bin/env bash
set -euo pipefail

# Tiny bootstrap script:
# - Downloads a release tarball or branch archive based on --ref
# - Verifies SHA256 checksum (release path only; skipped for branch archives and tag archive fallback)
# - Optionally verifies GPG signature for the checksum file (release path only)
# - Executes install.sh from extracted archive
#
# Usage (pinned release — recommended):
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --ref v1.2.3
#
# Usage (branch — unverified):
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --ref my-branch
#
# Usage (latest main branch — unverified, convenience only):
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash

REPO="johndotpub/dotfiles"

# Runtime flags forwarded to install.sh.
REF=""
HOST=""
PYVER=""
ASSUME_YES=0
NO_APT=0
BREW_ONLY=0
DRY_RUN=0
PRESERVE=0
VERBOSE=0
CREATE_HOME_PYVER=0
REPORT_JSON=""
NO_LOCK=0
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
Usage: bootstrap.sh [--ref <ref>] [--host <host>] [--pyver <ver>] [-y] [--no-apt] [--brew-only] [--dry-run] [--preserve] [--verbose] [--create-home-pyver] [--report-json <path>] [--no-lock]

  --ref <ref>          (optional) Download a specific release tag or branch.
                       Omit to install the latest main branch (no checksum verification).
  --preserve           Keep existing files untouched (passed through to install.sh).
  --verbose            Verbose logging (passed through to install.sh).
  --create-home-pyver  Create ~/.python-version (passed through to install.sh).
  --report-json <path> Write install report JSON to path (passed through to install.sh).
  --no-lock            Disable installer lock (passed through to install.sh).

Examples:
  # Pinned release (recommended — checksum-verified):
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --ref v1.2.3

  # Branch (unverified):
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --ref my-branch

  # Latest main branch (unverified — convenience):
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash
EOF
  exit "$code"
}

# Parse minimal bootstrap args and forward only supported installer flags.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) [[ $# -ge 2 ]] || { echo "--ref requires a <ref> argument"; usage 1; }
      REF="$2"; shift 2 ;;
    --host) [[ $# -ge 2 ]] || { echo "--host requires a <host> argument"; usage 1; }
      HOST="$2"; shift 2 ;;
    --pyver) [[ $# -ge 2 ]] || { echo "--pyver requires a <ver> argument"; usage 1; }
      PYVER="$2"; shift 2 ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --no-apt) NO_APT=1; shift ;;
    --brew-only) BREW_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --preserve) PRESERVE=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --create-home-pyver) CREATE_HOME_PYVER=1; shift ;;
    --install-inference)
      # Deprecated: inference tools are now plain brew packages.
      echo "⚠️  --install-inference is no longer needed; inference tools install via brew.yaml."
      shift ;;
    --report-json)
      [[ $# -ge 2 ]] || { echo "--report-json requires a <path> argument"; usage 1; }
      REPORT_JSON="$2"; shift 2 ;;
    --no-lock) NO_LOCK=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1"; usage 1 ;;
  esac
done

# build_install_args is sourced from scripts/lib/install-flags.sh inside the
# extracted repository (see each download path below).  That file is the single
# source of truth for which flags bootstrap.sh forwards to install.sh.

# Build release asset URLs from owner/repo + tag.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"

# Archive base URL; can be overridden via BOOTSTRAP_ARCHIVE_BASE for testing.
ARCHIVE_BASE="${BOOTSTRAP_ARCHIVE_BASE:-https://github.com/${REPO}/archive}"

# When --ref is omitted fall back to downloading the latest main branch archive.
# This path skips checksum and GPG verification because GitHub branch archives
# do not ship a .sha256 file; the user is warned before anything is executed.
if [[ -z "$REF" ]]; then
  # Override URL for integration tests; defaults to the GitHub archive endpoint.
  MAIN_URL="${BOOTSTRAP_MAIN_URL:-${ARCHIVE_BASE}/refs/heads/main.tar.gz}"
  ASSET_BASENAME="${REPO##*/}-main.tar.gz"

  echo "⚠️  No --ref provided: installing latest main branch (unverified)."
  echo "ℹ️  For a checksum-verified install, use: --ref <release-tag>"
  echo "📥 Downloading main branch archive..."
  curl -fsSLo "${ASSET_BASENAME}" -L "${MAIN_URL}"

  echo "📦 Extracting main branch archive..."
  mkdir -p repo
  tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
  cd repo
  chmod +x install.sh

  echo "🚀 Running installer..."
  install_args=(--from-release)
  # shellcheck source=scripts/lib/install-flags.sh
  source scripts/lib/install-flags.sh
  build_install_args

  ./install.sh "${install_args[@]}"
  echo "✅ Bootstrap complete."
  exit 0
fi

# Ref provided: resolve to branch, release tag, or tag archive via server probes.
# Detection order (server decides — no string-shape guessing):
#   1. HEAD probe to refs/heads/{ref}    → branch → archive download, skip checksum
#   2. HEAD probe to release asset URL   → release tag → full download + SHA256 + optional GPG
#   3. fallback refs/tags/{ref}          → tag archive → download, skip checksum, warn
ASSET_BASENAME="${REPO##*/}-${REF}.tar.gz"
BRANCH_ARCHIVE_URL="${ARCHIVE_BASE}/refs/heads/${REF}.tar.gz"
TAG_ARCHIVE_URL="${ARCHIVE_BASE}/refs/tags/${REF}.tar.gz"

# Release base URL; BOOTSTRAP_RELEASE_BASE can be set to override for testing.
RELEASE_BASE="${BOOTSTRAP_RELEASE_BASE:-https://github.com/${REPO}/releases/download/${REF}}"
RELEASE_ASSET_URL="${RELEASE_BASE}/${ASSET_BASENAME}"

echo "🔍 Resolving ref '${REF}'..."

# Step 1: probe refs/heads/{ref} — detect branch refs.
branch_status=$(curl -sI -L --max-time 10 -o /dev/null -w "%{http_code}" "${BRANCH_ARCHIVE_URL}" 2>/dev/null) || branch_status="000"

if [[ "$branch_status" == "200" ]]; then
  echo "⚠️  Skipping checksum verification for non-release ref '${REF}'."
  echo "📥 Downloading branch archive..."
  curl -fsSLo "${ASSET_BASENAME}" -L "${BRANCH_ARCHIVE_URL}"

  echo "📦 Extracting branch archive..."
  mkdir -p repo
  tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
  cd repo
  chmod +x install.sh

  echo "🚀 Running installer..."
  install_args=(--from-release --ref "$REF")
  # shellcheck source=scripts/lib/install-flags.sh
  source scripts/lib/install-flags.sh
  build_install_args

  ./install.sh "${install_args[@]}"
  echo "✅ Bootstrap complete."
  exit 0
fi

# Step 2: probe release asset — detect release tags with checksum assets.
release_status=$(curl -sI -L --max-time 10 -o /dev/null -w "%{http_code}" "${RELEASE_ASSET_URL}" 2>/dev/null) || release_status="000"

if [[ "$release_status" == "200" ]]; then
  # Release tag path: full download + SHA256 + optional GPG verification.
  echo "📥 Downloading release tarball..."
  curl -fsSLo "${ASSET_BASENAME}" -L "${RELEASE_ASSET_URL}"

  SHA_URL="${RELEASE_ASSET_URL}.sha256"
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
  install_args=(--from-release --ref "$REF")
  # shellcheck source=scripts/lib/install-flags.sh
  source scripts/lib/install-flags.sh
  build_install_args

  # Execute installer from the verified release payload.
  ./install.sh "${install_args[@]}"
  echo "✅ Bootstrap complete."
  exit 0
fi

# Step 3: fall back to refs/tags/{ref} archive — tag archive without release assets.
echo "⚠️  ref '${REF}' not found as a release asset; trying tag archive (unverified)."
echo "⚠️  Skipping checksum verification for non-release ref '${REF}'."
echo "📥 Downloading tag archive..."
curl -fsSLo "${ASSET_BASENAME}" -L "${TAG_ARCHIVE_URL}"

echo "📦 Extracting tag archive..."
mkdir -p repo
tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
cd repo
chmod +x install.sh

echo "🚀 Running installer..."
install_args=(--from-release --ref "$REF")
# shellcheck source=scripts/lib/install-flags.sh
source scripts/lib/install-flags.sh
build_install_args

./install.sh "${install_args[@]}"
echo "✅ Bootstrap complete."
