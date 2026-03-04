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

verify_checksum() {
  local checksum_file="$1"
  local artifact_file="$2"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "$checksum_file"
    return 0
  fi

  local expected actual
  expected="$(awk '{print $1}' "$checksum_file" | awk 'NR==1 {print $1}')"
  if [[ -z "$expected" ]]; then
    echo "❌ Could not parse expected SHA256 from ${checksum_file}."
    return 1
  fi

  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$artifact_file" | awk '{print $1}')"
  elif command -v python3 >/dev/null 2>&1; then
    actual="$(python3 - "$artifact_file" <<'PY'
import hashlib
import sys

path = sys.argv[1]
digest = hashlib.sha256()
with open(path, "rb") as f:
    while True:
        chunk = f.read(1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
print(digest.hexdigest())
PY
)"
  else
    echo "❌ No SHA256 tool found (need sha256sum, shasum, or python3)."
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

# Parse minimal bootstrap args.
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

# Build release asset URLs from owner/repo + tag.
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
# If a detached signature is published for the checksum, verify it.
if curl -fsSLo /dev/null "${SHA_SIG_URL}" 2>/dev/null; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "ℹ️ Skipping GPG verification: 'gpg' is not installed."
  else
    echo "🔐 Found checksum signature; verifying with gpg..."
    curl -fsSLo "${ASSET_BASENAME}.sha256.asc" "${SHA_SIG_URL}"
    if ! gpg --verify "${ASSET_BASENAME}.sha256.asc" "${ASSET_BASENAME}.sha256"; then
      echo "❌ GPG verification failed; aborting."
      exit 2
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
