#!/usr/bin/env bash
# Install metrics-server so Portainer and `kubectl top` can show CPU/RAM.
set -euo pipefail

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
helm repo update metrics-server >/dev/null

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi \
  --set resources.limits.memory=256Mi

echo
echo "Waiting for rollout..."
kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s
sleep 20
kubectl top nodes
