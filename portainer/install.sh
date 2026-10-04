#!/usr/bin/env bash
# Install Portainer CE (Kubernetes) as an on-demand deploy UI.
#
# Optional env vars:
#   NODE_NAME   pin Portainer to a specific node (single-node clusters)
#   NAMESPACE   defaults to "portainer"
set -euo pipefail

NAMESPACE="${NAMESPACE:-portainer}"

helm repo add portainer https://portainer.github.io/k8s/ >/dev/null 2>&1 || true
helm repo update portainer >/dev/null

ARGS=(
  --set image.tag=lts
  --set resources.requests.cpu=50m
  --set resources.requests.memory=128Mi
  --set resources.limits.cpu=750m
  --set resources.limits.memory=512Mi
)

if [[ -n "${NODE_NAME:-}" ]]; then
  ARGS+=(--set nodeSelector."kubernetes\.io/hostname=${NODE_NAME}")
fi

helm upgrade --install --create-namespace -n "${NAMESPACE}" portainer portainer/portainer "${ARGS[@]}"

echo
echo "Waiting for rollout..."
kubectl -n "${NAMESPACE}" rollout status deploy/portainer --timeout=180s
kubectl -n "${NAMESPACE}" get pod,svc,pvc
