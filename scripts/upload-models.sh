#!/usr/bin/env bash

set -euo pipefail
set +x

readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ARCHIVE="${REPOSITORY_ROOT}/build/models.zip"
readonly UPLOAD_URL="${DEV_DEPLOYMENT_UPLOAD_URL:-http://127.0.0.1:8080/upload}"

if [[ -z "${DEV_DEPLOYMENT_UPLOAD_API_KEY:-}" ]]; then
  echo "ERROR: DEV_DEPLOYMENT_UPLOAD_API_KEY must be set." >&2
  exit 1
fi

if [[ ! -s "${ARCHIVE}" ]]; then
  echo "ERROR: model archive does not exist or is empty: ${ARCHIVE}" >&2
  echo "Run scripts/package-models.sh first." >&2
  exit 1
fi

response_file="$(mktemp)"
cleanup() {
  rm -f "${response_file}"
}
trap cleanup EXIT INT TERM

if ! http_status="$(
  curl --silent --show-error --fail-with-body \
    --request POST \
    --form "myFile=@${ARCHIVE};type=application/zip" \
    --url "${UPLOAD_URL}" \
    --url-query "apiKey=${DEV_DEPLOYMENT_UPLOAD_API_KEY}" \
    --output "${response_file}" \
    --write-out '%{http_code}'
)"; then
  echo "ERROR: model upload failed." >&2
  sed -n '1,200p' "${response_file}" >&2
  exit 1
fi

if [[ ! "${http_status}" =~ ^2[0-9][0-9]$ ]]; then
  echo "ERROR: upload returned HTTP ${http_status}." >&2
  sed -n '1,200p' "${response_file}" >&2
  exit 1
fi

echo "Model upload completed successfully with HTTP ${http_status}."
if [[ -s "${response_file}" ]]; then
  sed -n '1,200p' "${response_file}"
fi
