#!/usr/bin/env bash
# Install the Tailscale Kubernetes Operator.
#
# Requires an OAuth client created in the Tailscale admin console with:
#   - Tag: tag:k8s-operator
#   - Scopes: Services (RW), Devices (RW), Auth Keys (RW)
#
# Export the credentials first (do NOT commit them):
#   export TS_OAUTH_CLIENT_ID=...
#   export TS_OAUTH_CLIENT_SECRET=...
set -euo pipefail

if [[ -z "${TS_OAUTH_CLIENT_ID:-}" || -z "${TS_OAUTH_CLIENT_SECRET:-}" ]]; then
  echo "ERROR: export TS_OAUTH_CLIENT_ID and TS_OAUTH_CLIENT_SECRET first" >&2
  exit 1
fi

helm repo add tailscale https://pkgs.tailscale.com/helmcharts >/dev/null 2>&1 || true
helm repo update tailscale >/dev/null

helm upgrade --install operator tailscale/tailscale-operator \
  --namespace tailscale \
  --create-namespace \
  --set-string oauth.clientId="${TS_OAUTH_CLIENT_ID}" \
  --set-string oauth.clientSecret="${TS_OAUTH_CLIENT_SECRET}" \
  --set-string apiServerProxyConfig.mode="true" \
  --wait

echo
echo "Operator pods:"
kubectl -n tailscale get pods
