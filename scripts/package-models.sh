#!/usr/bin/env bash

set -euo pipefail

readonly REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly MODELS_DIRECTORY="${REPOSITORY_ROOT}/models"
readonly BUILD_DIRECTORY="${REPOSITORY_ROOT}/build"
readonly ARCHIVE="${BUILD_DIRECTORY}/models.zip"

for command_name in find sort zip unzip; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -d "${MODELS_DIRECTORY}" ]]; then
  echo "ERROR: models directory does not exist: ${MODELS_DIRECTORY}" >&2
  exit 1
fi

mapfile -d '' -t model_files < <(
  cd "${MODELS_DIRECTORY}"
  find . -type f \( -iname '*.dmn' -o -iname '*.bpmn' \) -print0 |
    sort -z
)

if [[ "${#model_files[@]}" -eq 0 ]]; then
  echo "ERROR: no .dmn or .bpmn files were found in ${MODELS_DIRECTORY}." >&2
  exit 1
fi

mkdir -p "${BUILD_DIRECTORY}"
rm -f "${ARCHIVE}"

(
  cd "${MODELS_DIRECTORY}"
  zip -q "${ARCHIVE}" "${model_files[@]}"
)

echo "Created ${ARCHIVE} with:"
unzip -l "${ARCHIVE}"
