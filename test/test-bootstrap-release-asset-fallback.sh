#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fake_bin="${tmp_dir}/fakebin"
fixture_dir="${tmp_dir}/fixture"
mkdir -p "$fake_bin" "$fixture_dir"

payload_dir="${tmp_dir}/payload"
mkdir -p "$payload_dir"
cat > "${payload_dir}/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${BOOTSTRAP_TEST_ARGS_FILE}"
EOF
chmod +x "${payload_dir}/install.sh"

fixture_tarball="${fixture_dir}/default.skel-v1.0.0.tar.gz"
tar -czf "${fixture_tarball}" -C "${payload_dir}" .
fixture_sha="${fixture_tarball}.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  checksum="$(sha256sum "${fixture_tarball}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  checksum="$(shasum -a 256 "${fixture_tarball}" | awk '{print $1}')"
else
  echo "No SHA256 tool found (need sha256sum or shasum)."
  exit 1
fi
printf '%s  default.skel-v1.0.0.tar.gz\n' "$checksum" > "${fixture_sha}"

curl_log="${tmp_dir}/curl.log"
args_file="${tmp_dir}/install-args.log"

cat > "${fake_bin}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out_file=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -fsSLo|-o)
      out_file="$2"
      shift 2
      ;;
    -L)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

printf '%s\n' "$url" >> "${BOOTSTRAP_TEST_CURL_LOG}"

case "$url" in
  */skel-v1.0.0.tar.gz)
    exit 22
    ;;
  */default.skel-v1.0.0.tar.gz)
    cp "${BOOTSTRAP_TEST_FIXTURE_TARBALL}" "${out_file}"
    ;;
  */default.skel-v1.0.0.tar.gz.sha256)
    cp "${BOOTSTRAP_TEST_FIXTURE_SHA}" "${out_file}"
    ;;
  *.asc)
    exit 22
    ;;
  *)
    echo "unexpected curl url: ${url}" >&2
    exit 1
    ;;
esac
EOF
chmod +x "${fake_bin}/curl"

BOOTSTRAP_TEST_CURL_LOG="${curl_log}" \
BOOTSTRAP_TEST_FIXTURE_TARBALL="${fixture_tarball}" \
BOOTSTRAP_TEST_FIXTURE_SHA="${fixture_sha}" \
BOOTSTRAP_TEST_ARGS_FILE="${args_file}" \
PATH="${fake_bin}:${PATH}" \
bash "${REPO_DIR}/bootstrap.sh" --tag v1.0.0 --yes >/dev/null

if ! [[ -f "${args_file}" ]]; then
  echo "bootstrap did not execute install.sh payload"
  exit 1
fi

if ! grep -q -- "--from-release --tag v1.0.0 -y" "${args_file}"; then
  echo "bootstrap did not forward expected install args"
  cat "${args_file}"
  exit 1
fi

if ! sed -n '1p' "${curl_log}" | grep -q '/skel-v1.0.0.tar.gz$'; then
  echo "bootstrap did not try normalized asset first"
  cat "${curl_log}"
  exit 1
fi

if ! sed -n '2p' "${curl_log}" | grep -q '/default.skel-v1.0.0.tar.gz$'; then
  echo "bootstrap did not fallback to legacy hidden-asset name"
  cat "${curl_log}"
  exit 1
fi

echo "Bootstrap fallback asset test passed."
