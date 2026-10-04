# Private access + public exposure with Tailscale

Why Tailscale: most home ISPs (JioFiber, Airtel, etc.) put you behind **CGNAT**, so IPv4
port-forwarding does not work. Tailscale establishes an **outbound** WireGuard tunnel, so it works
behind any NAT, and Tailscale **Funnel** gives you a public HTTPS URL with **no domain and no
port-forwarding**.

Two access modes:

| Mode | Annotation | Who can reach it | URL |
|---|---|---|---|
| Private (Ingress) | *(none)* | Devices on your tailnet | `https://<name>.<tailnet>.ts.net` |
| Public (Funnel) | `tailscale.com/funnel: "true"` | Anyone on the internet | `https://<name>.<tailnet>.ts.net` |

## Prerequisites

- A Tailscale account with **admin** access.
- The admin machine's `tailscale` client logged into the **same tailnet you want to use**.
  Check with `tailscale status --json | jq -r .CurrentTailnet.MagicDNSSuffix`.
- `kubectl` + `helm`.

## Step 1 — Tailnet policy (ACL)

Go to <https://login.tailscale.com/admin/acls>, **switch to the correct tailnet** (top-left
switcher), merge in [`acl-policy.json`](acl-policy.json), and Save.

This defines `tag:k8s-operator`, `tag:k8s`, allows the operator to mint proxy nodes, and grants
the `funnel` attribute to proxy nodes. It keeps a permissive allow-all grant.

## Step 2 — OAuth client

<https://login.tailscale.com/admin/settings/trust-credentials> → **+ Credential**:

- Description: `cluster-operator`
- **Tag**: `tag:k8s-operator`
- **Scopes**: `Services` Read+Write, `Devices` Read+Write, `Auth Keys` Read+Write

Copy the **Client ID** and **Client Secret**.

> ⚠️ **Create it in the same tailnet as your devices.** A mismatch is the #1 gotcha — the operator
> will join a tailnet your laptop/phone are not in, and nothing will resolve.

## Step 3 — Enable MagicDNS, then HTTPS (order matters)

<https://login.tailscale.com/admin/dns>:

1. **Enable MagicDNS**.
2. **Enable HTTPS Certificates**.

MagicDNS must be enabled **before** HTTPS, otherwise the control plane will not grant proxy nodes
the certificate capability and the ingress will never get an address.

## Step 4 — Install the operator

```bash
export TS_OAUTH_CLIENT_ID=...
export TS_OAUTH_CLIENT_SECRET=...
./tailscale/install-operator.sh
```

## Step 5 — Private access to Portainer

```bash
kubectl apply -f tailscale/portainer-ingress.yaml
kubectl -n portainer get ingress -w        # wait for ADDRESS
```

Open `https://portainer.<tailnet>.ts.net` from any device on your tailnet.

## Step 6 — Public app (test)

```bash
kubectl apply -f tailscale/demo-funnel-app.yaml
kubectl get ingress -A                     # whoami -> https://whoami.<tailnet>.ts.net
```

Open it from a phone on cellular (Tailscale off) to confirm public access.

## Verify

```bash
# is the proxy node in the tailnet?
tailscale status | grep -E 'portainer|whoami'
# from any tailnet device
curl -sI https://portainer.<tailnet>.ts.net/
# public reachability (DNS may take up to ~20 min the first time)
dig @1.1.1.1 whoami.<tailnet>.ts.net A +short
```

## Gotchas (learned the hard way)

- **Tailnet mismatch** → create OAuth creds in the tailnet your devices are in.
- **HTTPS enabled but no TLS** → the proxy started *before* HTTPS was enabled; it needs a restart
  (`kubectl -n tailscale delete pod -l app=...` or delete the specific `ts-<name>-*` pod).
- **MagicDNS disabled** → HTTPS cert capability is not granted; Funnel/Ingress never get an address.
- **Funnel public DNS is slow** → docs say "up to 10 minutes", observed ~20. Be patient before debugging.
- **`invalid-packet-filter ... unlocked nodes`** log line → usually cosmetic here; private and public
  paths still work. If it breaks traffic, simplify the ACL grants.
- Funnel is **TLS-only**, ports **443/8443/10000**, and bandwidth-throttled. For arbitrary TCP/UDP
  (game servers) prefer private Ingress, or add a domain + Cloudflare Tunnel later.
