#!/usr/bin/env bash

set -euo pipefail

readonly EXPECTED_CONTEXT="kind-kie-local"
readonly NAMESPACE="kie-dev"
readonly APP_LABEL="app.kubernetes.io/instance=kie-runtime"
readonly LOCAL_PORT="8080"
readonly REMOTE_PORT="8080"

port_forward_pid=""
temp_dir="$(mktemp -d)"
port_forward_log="${temp_dir}/port-forward.log"
openapi_file="${temp_dir}/openapi.yaml"

cleanup() {
  if [[ -n "${port_forward_pid}" ]] && kill -0 "${port_forward_pid}" 2>/dev/null; then
    kill "${port_forward_pid}" 2>/dev/null || true
    wait "${port_forward_pid}" 2>/dev/null || true
  fi
  rm -rf "${temp_dir}"
}
trap cleanup EXIT INT TERM

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    exit 1
  fi
}

for command_name in kubectl curl mktemp; do
  require_command "${command_name}"
done

current_context="$(kubectl config current-context)"
if [[ "${current_context}" != "${EXPECTED_CONTEXT}" ]]; then
  echo "ERROR: current Kubernetes context is '${current_context}', expected '${EXPECTED_CONTEXT}'." >&2
  exit 1
fi
echo "Kubernetes context confirmed: ${current_context}"

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: namespace '${NAMESPACE}' does not exist." >&2
  exit 1
fi
echo "Namespace confirmed: ${NAMESPACE}"

mapfile -t services < <(
  kubectl -n "${NAMESPACE}" get services \
    -l "${APP_LABEL}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
)

if [[ "${#services[@]}" -ne 1 ]] || [[ -z "${services[0]}" ]]; then
  echo "ERROR: expected exactly one Service with label '${APP_LABEL}', found ${#services[@]}." >&2
  exit 1
fi
service_name="${services[0]}"
echo "Service found: ${service_name}"

kubectl -n "${NAMESPACE}" port-forward \
  "service/${service_name}" \
  "${LOCAL_PORT}:${REMOTE_PORT}" \
  >"${port_forward_log}" 2>&1 &
port_forward_pid="$!"

echo "Waiting for the application on 127.0.0.1:${LOCAL_PORT}..."
for _ in {1..60}; do
  if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
    echo "ERROR: port-forward terminated unexpectedly." >&2
    sed -n '1,200p' "${port_forward_log}" >&2
    exit 1
  fi
  if curl --silent --show-error --fail \
    "http://127.0.0.1:${LOCAL_PORT}/q/health" \
    >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

health_code="$(
  curl --silent --show-error \
    --output "${temp_dir}/health.json" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:${LOCAL_PORT}/q/health"
)"
if [[ "${health_code}" != "200" ]]; then
  echo "ERROR: /q/health returned HTTP ${health_code}." >&2
  exit 1
fi
echo "/q/health: HTTP ${health_code}"

openapi_code="$(
  curl --silent --show-error \
    --output "${openapi_file}" \
    --write-out '%{http_code}' \
    "http://127.0.0.1:${LOCAL_PORT}/q/openapi"
)"
if [[ "${openapi_code}" != "200" ]] || [[ ! -s "${openapi_file}" ]]; then
  echo "ERROR: /q/openapi returned HTTP ${openapi_code} or an empty document." >&2
  exit 1
fi
echo "/q/openapi: HTTP ${openapi_code}; temporary document size: $(wc -c <"${openapi_file}") bytes"
echo "Deployment smoke test completed successfully."
