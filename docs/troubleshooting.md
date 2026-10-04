# Troubleshooting

Issues actually hit while building this stack, with fixes.

## Storage

**PVC stuck `Pending` with `violates PodSecurity "baseline:latest": hostPath volumes`**
local-path-provisioner creates a helper Pod that uses `hostPath`. Allow privileged Pod Security on
its namespace:

```bash
kubectl label ns local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite
```

**PVC `Pending` forever, no events**
That is normal for `volumeBindingMode: WaitForFirstConsumer` — it binds once a Pod mounts it.

## Portainer

**"Your Portainer instance has timed out for security purposes"**
CE halts 5 minutes after first start unless an admin exists. There is no timeout setting — pre-create
the admin with `adminPassword.existingSecret` (see `portainer/README.md`).

**Can't reach the UI**
Default NodePort is `30777` (HTTP) / `30779` (HTTPS):

```bash
kubectl -n portainer get svc portainer
curl -o /dev/null -w '%{http_code}\n' http://<NODE_IP>:30777/
```

## Tailscale operator / access

**Ingress created but `ADDRESS` stays empty**
1. **Wrong tailnet**: the OAuth client was created in a different tailnet than your devices.
   Verify:
   ```bash
   tailscale status --json | jq -r .CurrentTailnet.MagicDNSSuffix   # your devices' tailnet
   # OAuth client's tailnet:
   TOKEN=$(curl -s -X POST https://api.tailscale.com/api/v2/oauth/token \
     -d client_id=$ID -d client_secret=$SECRET -d grant_type=client_credentials | jq -r .access_token)
   curl -s -H "Authorization: Bearer $TOKEN" https://api.tailscale.com/api/v2/tailnet/-/devices | jq -r '.devices[].name'
   ```
   Recreate the OAuth client in the correct tailnet and reinstall.
2. **MagicDNS not enabled**: the proxy cannot get a cert capability.
   On the proxy pod you'll see:
   ```
   serve proxy: ... it is not able to issue TLS certs ... ensure that HTTPS is enabled ...
   ```
   Enable MagicDNS **then** HTTPS in the admin console, then restart the proxy pods:
   ```bash
   kubectl -n tailscale get pods
   kubectl -n tailscale delete pod <ts-NAME>-0
   ```

**Proxy joined the wrong/old tailnet earlier**
```bash
helm uninstall operator -n tailscale
kubectl delete ns tailscale
# list & delete stray devices via the OAuth API, then reinstall with correct creds
```

## Funnel

**Funnel on locally but URL not reachable / public DNS empty**
`tailscale funnel status` inside the proxy shows:
```
https://whoami.<tailnet>.ts.net (Funnel on)
|-- / proxy http://...
```
Public DNS can take **~10–20 minutes** to publish. Check authoritative resolution:

```bash
dig @1.1.1.1 whoami.<tailnet>.ts.net A +short
```

If it never appears, confirm the proxy node has the capability:

```bash
kubectl -n tailscale exec <ts-whoami-pod> -c tailscale -- \
  sh -c 'tailscale status --json | grep -A2 Capabilities'
# want to see: "funnel", "https://tailscale.com/cap/funnel-ports?..."
```

**`invalid-packet-filter ... unlocked nodes; rejecting all packets`**
Usually cosmetic in this setup (private and public still work). If traffic actually breaks,
simplify the ACL `grants` so it does not grant `dst: ["*"]` to all nodes.

## Kubernetes / Talos

**Pods stuck `Pending` on a single node**
Remove the control-plane taint:
```bash
kubectl taint nodes <NODE_NAME> node-role.kubernetes.io/control-plane:NoSchedule-
```

**`kubectl` suddenly can't connect after a reboot**
The node's DHCP address changed. Set a static IP / DHCP reservation for the node.
