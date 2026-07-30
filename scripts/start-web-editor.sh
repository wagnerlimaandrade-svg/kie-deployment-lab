#!/usr/bin/env bash

set -euo pipefail

readonly LAB_CONTEXT="${KIE_LAB_CONTEXT:-kind-kie-local}"
readonly LAB_CLUSTER_NAME="${KIE_LAB_CLUSTER_NAME:-kie-local}"
readonly LAB_NAMESPACE="${KIE_LAB_EDITOR_NAMESPACE:-local-kie-sandbox-dev-deployments}"
readonly LAB_INGRESS_PORT="${KIE_LAB_INGRESS_PORT:-8081}"
readonly EDITOR_PORT="${KIE_LAB_EDITOR_PORT:-9001}"
readonly UPSTREAM_REPO="${KIE_TOOLS_REPO:-../upstream-kie-tools}"
readonly EDITOR_PACKAGE="${UPSTREAM_REPO}/packages/online-editor"
readonly CLUSTER_RESOURCES="${EDITOR_PACKAGE}/static/dev-deployments/kubernetes/cluster-config/kie-sandbox-dev-deployments-resources.yaml"
readonly LAB_OFFLINE_IMAGE="${KIE_LAB_OFFLINE_IMAGE:-kie-dev-deployment-offline:latest}"
readonly EDITOR_RUNTIME_IMAGE="apache/incubator-kie-sandbox-dev-deployment-quarkus-blank-app:main"

port_forward_pid=""
editor_pid=""

cleanup() {
  for process_id in "${editor_pid}" "${port_forward_pid}"; do
    if [[ -n "${process_id}" ]] && kill -0 "${process_id}" 2>/dev/null; then
      kill "${process_id}" 2>/dev/null || true
      wait "${process_id}" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT INT TERM

for command_name in curl docker kind kubectl pnpm; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${command_name}" >&2
    exit 1
  fi
done

if [[ ! -f "${EDITOR_PACKAGE}/package.json" || ! -f "${CLUSTER_RESOURCES}" ]]; then
  echo "ERROR: upstream KIE Tools checkout not found at '${UPSTREAM_REPO}'." >&2
  echo "Set KIE_TOOLS_REPO to its path and try again." >&2
  exit 1
fi

if docker image inspect "${LAB_OFFLINE_IMAGE}" >/dev/null 2>&1; then
  echo "Synchronizing the lab offline-ready image with the editor runtime tag..."
  docker tag "${LAB_OFFLINE_IMAGE}" "${EDITOR_RUNTIME_IMAGE}"
  kind load docker-image "${EDITOR_RUNTIME_IMAGE}" --name "${LAB_CLUSTER_NAME}"
else
  echo "WARNING: '${LAB_OFFLINE_IMAGE}' was not found locally." >&2
  echo "New deployments will use the upstream image configured by KIE Sandbox." >&2
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
  >/tmp/kie-lab-editor-port-forward.log 2>&1 &
port_forward_pid="$!"

for _ in {1..30}; do
  if curl --fail --silent --max-time 2 \
    "http://localhost:${LAB_INGRESS_PORT}/kube-apiserver/version" \
    >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "${port_forward_pid}" 2>/dev/null; then
    echo "ERROR: lab Ingress port-forward terminated unexpectedly." >&2
    sed -n '1,120p' /tmp/kie-lab-editor-port-forward.log >&2
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
    cd "${EDITOR_PACKAGE}"
    pnpm start
  ) &
  editor_pid="$!"

  for _ in {1..120}; do
    if curl --fail --silent --max-time 2 \
      "http://localhost:${EDITOR_PORT}/env.json" >/dev/null 2>&1; then
      break
    fi
    if ! kill -0 "${editor_pid}" 2>/dev/null; then
      echo "ERROR: KIE Sandbox terminated before becoming ready." >&2
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
