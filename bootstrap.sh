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

TAG=""
HOST=""
PYVER=""
ASSUME_YES=0

usage() {
  local code="${1:-1}"
  cat <<EOF
Usage: bootstrap.sh --tag <tag> [--host <host>] [--pyver <ver>] [-y]
Example:
  curl -fsSL https://<your-pages-domain>/bootstrap.sh | bash -s -- --tag v1.2.3
EOF
  exit "$code"
}

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

if [[ -z "$TAG" ]]; then
  echo "❌ Error: --tag is required"
  usage 1
fi

TMPDIR="$(mktemp -d)"
ASSET_BASENAME="${REPO##*/}-${TAG}.tar.gz"
RELEASE_BASE="https://github.com/${REPO}/releases/download/${TAG}"
TARBALL_URL="${RELEASE_BASE}/${ASSET_BASENAME}"
SHA_URL="${TARBALL_URL}.sha256"
SHA_SIG_URL="${SHA_URL}.asc"

cd "$TMPDIR"
echo "📥 Downloading release tarball..."
curl -fsSLo "${ASSET_BASENAME}" "${TARBALL_URL}"

echo "📥 Downloading checksum..."
curl -fsSLo "${ASSET_BASENAME}.sha256" "${SHA_URL}"

# Optional GPG verification for checksum file
if curl -fsSLo /dev/null "${SHA_SIG_URL}" 2>/dev/null; then
  echo "🔐 Found checksum signature; verifying with gpg..."
  curl -fsSLo "${ASSET_BASENAME}.sha256.asc" "${SHA_SIG_URL}"
  if ! gpg --verify "${ASSET_BASENAME}.sha256.asc" "${ASSET_BASENAME}.sha256"; then
    echo "❌ GPG verification failed; aborting."
    exit 2
  fi
fi

echo "🧾 Verifying checksum..."
sha256sum -c "${ASSET_BASENAME}.sha256"

echo "📦 Extracting release..."
mkdir -p repo
tar -xzf "${ASSET_BASENAME}" -C repo --strip-components=1
cd repo
chmod +x install.sh

echo "🚀 Running installer..."
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

./install.sh "${install_args[@]}"
echo "✅ Bootstrap complete."
