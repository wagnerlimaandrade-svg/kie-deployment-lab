#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LAB_CONTEXT="${KIE_LAB_CONTEXT:-kind-kie-local}"
readonly LAB_CLUSTER_NAME="${KIE_LAB_CLUSTER_NAME:-kie-local}"
readonly LAB_NAMESPACE="${KIE_LAB_EDITOR_NAMESPACE:-local-kie-sandbox-dev-deployments}"
readonly LAB_INGRESS_PORT="${KIE_LAB_INGRESS_PORT:-8081}"
readonly EDITOR_PORT="${KIE_LAB_EDITOR_PORT:-9001}"
readonly EDITOR_IMAGE="${KIE_LAB_EDITOR_IMAGE:-docker.io/apache/incubator-kie-sandbox-webapp:main}"
readonly EDITOR_CONTAINER="${KIE_LAB_EDITOR_CONTAINER:-kie-lab-web-editor}"
readonly CLUSTER_RESOURCES="${REPOSITORY_ROOT}/kind/kie-sandbox-dev-deployments-resources.yaml"
readonly LAB_OFFLINE_IMAGE="${KIE_LAB_OFFLINE_IMAGE:-kie-dev-deployment-offline:latest}"
readonly EDITOR_RUNTIME_IMAGE="apache/incubator-kie-sandbox-dev-deployment-quarkus-blank-app:main"

# shellcheck source=scripts/lib/platform.sh
source "${SCRIPT_DIR}/lib/platform.sh"

temp_dir="$(mktemp -d)"
port_forward_log="${temp_dir}/editor-port-forward.log"

port_forward_pid=""
editor_pid=""

cleanup() {
  for process_id in "${editor_pid}" "${port_forward_pid}"; do
    kie_lab_stop_process "${process_id}"
  done
  if [[ -n "${editor_pid}" ]]; then
    docker stop "${EDITOR_CONTAINER}" >/dev/null 2>&1 || true
  fi
  rm -rf "${temp_dir}"
}
trap cleanup EXIT INT TERM

for command_name in curl docker kind kubectl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${CLUSTER_RESOURCES}" ]]; then
  echo "ERROR: local cluster resources not found: ${CLUSTER_RESOURCES}" >&2
  exit 1
fi

if docker image inspect "${LAB_OFFLINE_IMAGE}" >/dev/null 2>&1; then
  echo "Synchronizing the lab offline-ready image with the editor runtime tag..."
  docker tag "${LAB_OFFLINE_IMAGE}" "${EDITOR_RUNTIME_IMAGE}"
  kind load docker-image "${EDITOR_RUNTIME_IMAGE}" --name "${LAB_CLUSTER_NAME}"
else
  echo "WARNING: '${LAB_OFFLINE_IMAGE}' was not found locally." >&2
  echo "New deployments will use the published image configured by KIE Sandbox." >&2
  echo "Run scripts/deploy-official.sh first to build the lab's offline-ready image." >&2
fi

kubectl --context "${LAB_CONTEXT}" apply -f "${CLUSTER_RESOURCES}"
kubectl --context "${LAB_CONTEXT}" wait \
  --namespace default \
  --for=condition=Ready pod/kube-apiserver-proxy \
  --timeout=120s
kubectl --context "${LAB_CONTEXT}" wait \
  --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl --context "${LAB_CONTEXT}" \
  --namespace ingress-nginx \
  port-forward service/ingress-nginx-controller "${LAB_INGRESS_PORT}:80" \
  >"${port_forward_log}" 2>&1 &
port_forward_pid="$!"

for _ in {1..30}; do
  if curl --fail --silent --max-time 2 \
    "http://localhost:${LAB_INGRESS_PORT}/kube-apiserver/version" \
    >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
    echo "ERROR: lab Ingress port-forward terminated unexpectedly." >&2
    sed -n '1,120p' "${port_forward_log}" >&2
    exit 1
  fi
  sleep 1
done

if ! curl --fail --silent --max-time 5 \
  "http://localhost:${LAB_INGRESS_PORT}/kube-apiserver/version" \
  >/dev/null; then
  echo "ERROR: lab Kubernetes API proxy is not reachable." >&2
  exit 1
fi

if ! curl --fail --silent --max-time 2 \
  "http://localhost:${EDITOR_PORT}/env.json" >/dev/null 2>&1; then
  (
    docker run --rm \
      --name "${EDITOR_CONTAINER}" \
      --publish "127.0.0.1:${EDITOR_PORT}:8080" \
      --env "KIE_SANDBOX_DEV_DEPLOYMENT_QUARKUS_BLANK_APP_IMAGE_URL=${EDITOR_RUNTIME_IMAGE}" \
      --env "KIE_SANDBOX_DEV_DEPLOYMENT_IMAGE_PULL_POLICY=IfNotPresent" \
      "${EDITOR_IMAGE}"
  ) &
  editor_pid="$!"

  for _ in {1..120}; do
    if curl --fail --silent --max-time 2 \
      "http://localhost:${EDITOR_PORT}/env.json" >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "${editor_pid}" 2>/dev/null; then
      echo "ERROR: KIE Sandbox container terminated before becoming ready." >&2
      exit 1
    fi
    sleep 1
  done
fi

if ! curl --fail --silent --max-time 5 \
  "http://localhost:${EDITOR_PORT}/env.json" >/dev/null; then
  echo "ERROR: KIE Sandbox is not reachable." >&2
  exit 1
fi

echo
echo "KIE Sandbox: http://localhost:${EDITOR_PORT}"
echo "Kubernetes host: http://localhost:${LAB_INGRESS_PORT}/kube-apiserver"
echo "Namespace: ${LAB_NAMESPACE}"
echo "Token command:"
echo "  kubectl --context ${LAB_CONTEXT} get secret kie-sandbox-secret --namespace default -o jsonpath='{.data.token}' | base64 --decode"
echo
echo "Keep this process running while using the editor. Press Ctrl+C to stop."

if [[ -n "${editor_pid}" ]]; then
  wait "${editor_pid}"
else
  wait "${port_forward_pid}"
fi
