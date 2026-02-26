#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-reverse}"
RELEASE_NAME="${RELEASE_NAME:-reverse}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY:-sofinvalery/devops}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
CHART_PATH="${CHART_PATH:-./helm/reverse}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install "${RELEASE_NAME}" "${CHART_PATH}" \
  --namespace "${NAMESPACE}" \
  --set image.repository="${IMAGE_REPOSITORY}" \
  --set image.tag="${IMAGE_TAG}"

echo "Application deployed: ${RELEASE_NAME} in namespace ${NAMESPACE}."
