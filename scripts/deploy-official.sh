#!/usr/bin/env bash

set -euo pipefail
set +x

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/lib/platform.sh
source "${SCRIPT_DIR}/lib/platform.sh"

readonly CLUSTER_NAME="kie-local"
readonly EXPECTED_CONTEXT="kind-${CLUSTER_NAME}"
readonly NAMESPACE="kie-dev"
readonly APP_LABEL="app.kubernetes.io/instance=kie-runtime"
readonly LOCAL_PORT="8080"
readonly RUNTIME_TIMEOUT_SECONDS="${DEV_DEPLOYMENT_RUNTIME_TIMEOUT_SECONDS:-600}"

temp_dir="$(mktemp -d)"
port_forward_pid=""

cleanup() {
  kie_lab_stop_process "${port_forward_pid}"
  rm -rf "${temp_dir}"
}
trap cleanup EXIT INT TERM

for command_name in curl docker kind kubectl skaffold; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ -z "${DEV_DEPLOYMENT_UPLOAD_API_KEY:-}" ]]; then
  echo "ERROR: DEV_DEPLOYMENT_UPLOAD_API_KEY must be set." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not available." >&2
  exit 1
fi

if ! kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  echo "Creating Kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}"
fi

# A Kind cluster can remain registered while its control-plane is stopped.
docker start "${CLUSTER_NAME}-control-plane" >/dev/null 2>&1 || true

kubectl config use-context "${EXPECTED_CONTEXT}" >/dev/null
kubectl create namespace "${NAMESPACE}" \
  --dry-run=client \
  --output=yaml |
  kubectl apply -f -

bash "${SCRIPT_DIR}/create-upload-secret.sh"
bash "${SCRIPT_DIR}/package-models.sh"
(cd "${REPOSITORY_ROOT}" && skaffold run -p official)

# A new pod guarantees that the one-shot upload service is available even
# when the playbook is executed repeatedly with an unchanged image digest.
kubectl -n "${NAMESPACE}" rollout restart deployment/kie-runtime
kubectl -n "${NAMESPACE}" rollout status \
  deployment/kie-runtime \
  --timeout="${RUNTIME_TIMEOUT_SECONDS}s"

kubectl -n "${NAMESPACE}" port-forward \
  service/kie-runtime \
  "${LOCAL_PORT}:8080" \
  >"${temp_dir}/upload-port-forward.log" 2>&1 &
port_forward_pid="$!"

for _ in {1..30}; do
  if grep -q "Forwarding from" "${temp_dir}/upload-port-forward.log"; then
    break
  fi
  if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
    echo "ERROR: upload port-forward terminated unexpectedly." >&2
    sed -n '1,160p' "${temp_dir}/upload-port-forward.log" >&2
    exit 1
  fi
  sleep 1
done

if ! grep -q "Forwarding from" "${temp_dir}/upload-port-forward.log"; then
  echo "ERROR: upload port-forward did not become ready." >&2
  sed -n '1,160p' "${temp_dir}/upload-port-forward.log" >&2
  exit 1
fi

bash "${SCRIPT_DIR}/upload-models.sh"

# The upload server exits while Quarkus compiles, which closes this first
# port-forward. That transition is expected; the smoke test opens a new one.
kie_lab_stop_process "${port_forward_pid}"
port_forward_pid=""

echo "Waiting for Quarkus to finish the offline compilation..."
deadline="$((SECONDS + RUNTIME_TIMEOUT_SECONDS))"
while (( SECONDS < deadline )); do
  pod_name="$(
    kubectl -n "${NAMESPACE}" get pods \
      -l "${APP_LABEL}" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"
  if [[ -n "${pod_name}" ]] &&
    kubectl -n "${NAMESPACE}" logs "${pod_name}" 2>/dev/null |
      grep -q "Listening on: http://0.0.0.0:8080"; then
    bash "${SCRIPT_DIR}/test-deployment.sh"
    echo "Official dev deployment completed successfully."
    exit 0
  fi
  sleep 5
done

echo "ERROR: Quarkus did not start within ${RUNTIME_TIMEOUT_SECONDS}s." >&2
kubectl -n "${NAMESPACE}" get pods >&2 || true
kubectl -n "${NAMESPACE}" logs deployment/kie-runtime --tail=200 >&2 || true
exit 1
