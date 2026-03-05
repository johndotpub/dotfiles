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
ASSET_BASENAME="${REPO##*/}-${TAG}.tar.gz"
RELEASE_BASE="https://github.com/${REPO}/releases/download/${TAG}"
TARBALL_URL="${RELEASE_BASE}/${ASSET_BASENAME}"
SHA_URL="${TARBALL_URL}.sha256"
SHA_SIG_URL="${SHA_URL}.asc"

cd "$TMPDIR"
echo "📥 Downloading release tarball..."
curl -fsSLo "${ASSET_BASENAME}" -L "${TARBALL_URL}"

echo "📥 Downloading checksum..."
curl -fsSLo "${ASSET_BASENAME}.sha256" -L "${SHA_URL}"

# Optional GPG verification for checksum file
# If a detached signature is published for the checksum, verify it.
if curl -fsSLo /dev/null -L "${SHA_SIG_URL}" 2>/dev/null; then
  if ! command -v gpg >/dev/null 2>&1; then
    echo "ℹ️ Skipping GPG verification: 'gpg' is not installed."
  else
    echo "🔐 Found checksum signature; verifying with gpg..."
    curl -fsSLo "${ASSET_BASENAME}.sha256.asc" -L "${SHA_SIG_URL}"
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
