#!/usr/bin/env bash

set -euo pipefail

readonly EXPECTED_CONTEXT="kind-kie-local"
readonly NAMESPACE="kie-dev"
readonly SECRET_NAME="${DEV_DEPLOYMENT_UPLOAD_SECRET_NAME:-kie-dev-deployment-upload}"
readonly SECRET_KEY_NAME="${DEV_DEPLOYMENT_UPLOAD_SECRET_KEY_NAME:-api-key}"

if [[ -z "${DEV_DEPLOYMENT_UPLOAD_API_KEY:-}" ]]; then
  echo "ERROR: DEV_DEPLOYMENT_UPLOAD_API_KEY must be set." >&2
  exit 1
fi

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: current Kubernetes context is '${current_context}', expected '${EXPECTED_CONTEXT}'." >&2
  exit 1
fi

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace '${NAMESPACE}' does not exist." >&2
  exit 1
fi

printf '%s' "${DEV_DEPLOYMENT_UPLOAD_API_KEY}" |
  kubectl -n "${NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-file="${SECRET_KEY_NAME}=/dev/stdin" \
    --dry-run=client \
    --output=yaml |
  kubectl apply -f -

echo "Upload Secret '${SECRET_NAME}' is configured in namespace '${NAMESPACE}'."
