#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-reverse}"
RELEASE_NAME="${RELEASE_NAME:-reverse}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-sofinvalery/devops}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CHART_PATH="${CHART_PATH:-./helm/reverse}"
HELM_FORCE_CONFLICTS="${HELM_FORCE_CONFLICTS:-true}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

HELM_ARGS=()
if [ "${HELM_FORCE_CONFLICTS}" = "true" ]; then
  HELM_ARGS+=(--force-conflicts)
fi

helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --set image.repository="${IMAGE_REPOSITORY}" \
  --set image.tag="${IMAGE_TAG}" \
  "${HELM_ARGS[@]}"

echo "Application deployed: ${RELEASE_NAME} in namespace ${NAMESPACE}."
