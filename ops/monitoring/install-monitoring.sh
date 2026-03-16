#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-monitoring}"
RELEASE_NAME="${RELEASE_NAME:-kube-prometheus-stack}"
VALUES_FILE="${VALUES_FILE:-ops/monitoring/kube-prometheus-stack-values.yaml}"
DASHBOARD_NAME="${DASHBOARD_NAME:-reverse-app-dashboard}"
DASHBOARD_FILE="${DASHBOARD_FILE:-${SCRIPT_DIR}/../grafana/reverse-dashboard.json}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  --values "${VALUES_FILE}"

if [ -f "${DASHBOARD_FILE}" ]; then
  kubectl -n "${NAMESPACE}" create configmap "${DASHBOARD_NAME}" \
    --from-file=reverse-dashboard.json="${DASHBOARD_FILE}" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "${NAMESPACE}" label configmap "${DASHBOARD_NAME}" grafana_dashboard=1 --overwrite
  echo "Grafana dashboard provisioned: ${DASHBOARD_NAME}"
else
  echo "Warning: dashboard file not found: ${DASHBOARD_FILE}"
fi

echo "Monitoring stack installed in namespace ${NAMESPACE}."
