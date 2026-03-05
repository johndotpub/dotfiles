#!/usr/bin/env bash
set -euo pipefail

# Tiny bootstrap script:
# - Downloads a release tarball
# - Verifies SHA256 checksum
# - Optionally verifies GPG signature for the checksum file
# - Executes install.sh from extracted archive
#
# Usage:
#   curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.2.3

REPO="johndotpub/.skel"

# Runtime flags forwarded to install.sh.
TAG=""
HOST=""
PYVER=""
ASSUME_YES=0
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
Usage: bootstrap.sh --tag <tag> [--host <host>] [--pyver <ver>] [-y]
Example:
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.2.3
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
    -h|--help) usage 0 ;;
    *) echo "Unknown arg: $1"; usage 1 ;;
  esac
done

# Bootstrap always requires a release tag so downloaded assets are explicit.
if [[ -z "$TAG" ]]; then
  echo "❌ Error: --tag is required"
  usage 1
fi

# Build release asset URLs from owner/repo + tag.
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
RELEASE_BASE="https://github.com/${REPO}/releases/download/${TAG}"
RAW_REPO_NAME="${REPO##*/}"
NORMALIZED_REPO_NAME="${RAW_REPO_NAME#.}"
if [[ -z "$NORMALIZED_REPO_NAME" ]]; then
  NORMALIZED_REPO_NAME="repo"
fi
ASSET_BASENAME="${NORMALIZED_REPO_NAME}-${TAG}.tar.gz"
TARBALL_URL="${RELEASE_BASE}/${ASSET_BASENAME}"

cd "$TMPDIR"
echo "📥 Downloading release tarball..."
if ! curl -fsSLo "${ASSET_BASENAME}" -L "${TARBALL_URL}"; then
  # Backward compatibility for v1.0.0 where hidden asset names were
  # rewritten to `default.<repo>-<tag>.tar.gz` by release tooling.
  if [[ "${RAW_REPO_NAME}" == .* ]]; then
    LEGACY_ASSET_BASENAME="default${RAW_REPO_NAME}-${TAG}.tar.gz"
    LEGACY_TARBALL_URL="${RELEASE_BASE}/${LEGACY_ASSET_BASENAME}"
    if curl -fsSLo "${LEGACY_ASSET_BASENAME}" -L "${LEGACY_TARBALL_URL}"; then
      ASSET_BASENAME="${LEGACY_ASSET_BASENAME}"
      TARBALL_URL="${LEGACY_TARBALL_URL}"
    else
      echo "❌ Unable to download release tarball for tag ${TAG}."
      echo "Tried:"
      echo "  - ${RELEASE_BASE}/${NORMALIZED_REPO_NAME}-${TAG}.tar.gz"
      echo "  - ${RELEASE_BASE}/default${RAW_REPO_NAME}-${TAG}.tar.gz"
      exit 1
    fi
  else
    echo "❌ Unable to download release tarball for tag ${TAG}: ${TARBALL_URL}"
    exit 1
  fi
fi

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

# Execute installer from the verified release payload.
./install.sh "${install_args[@]}"
echo "✅ Bootstrap complete."
