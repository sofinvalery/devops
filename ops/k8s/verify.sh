#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-reverse}"
RELEASE_NAME="${RELEASE_NAME:-reverse}"
NODE_IP="${NODE_IP:-}"

kubectl -n "${NAMESPACE}" rollout status deployment/"${RELEASE_NAME}" --timeout=180s
kubectl -n "${NAMESPACE}" get deploy,po,svc,hpa

NODE_PORT="$(kubectl -n "${NAMESPACE}" get svc "${RELEASE_NAME}" -o jsonpath='{.spec.ports[0].nodePort}')"
if [ -z "${NODE_IP}" ]; then
  NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
fi

if [ -z "${NODE_IP}" ] || [ -z "${NODE_PORT}" ]; then
  echo "Could not detect NODE_IP or NODE_PORT. Set NODE_IP manually and retry."
  exit 1
fi

echo "Checking health endpoint: http://${NODE_IP}:${NODE_PORT}/healthz"
curl -fsS "http://${NODE_IP}:${NODE_PORT}/healthz"
echo

echo "Checking metrics endpoint: http://${NODE_IP}:${NODE_PORT}/metrics"
curl -fsS "http://${NODE_IP}:${NODE_PORT}/metrics" | head -n 20
echo

echo "Verification finished."
