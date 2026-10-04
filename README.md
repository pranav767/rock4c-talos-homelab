# Rock 4 C+ Talos Homelab

Turn a **Radxa Rock 4 C+ running Talos Linux** into a small self-hosted Kubernetes box that is:

- **reachable from anywhere** (private, via Tailscale) — even behind ISP **CGNAT**,
- able to **expose apps to the public internet** over HTTPS (via Tailscale Funnel) — **no domain,
  no port-forwarding**,
- able to **deploy containers/apps on demand** from a web UI (Portainer CE),
- backed by **persistent storage** on a data disk (local-path-provisioner).

Everything here is declarative infrastructure + step-by-step docs. No secrets.

> Tested on: Rock 4 C+ (arm64), 4 GB RAM, Talos ~v1.13, Kubernetes ~v1.3x, single node.

## Architecture

```
You (browser / kubectl / phone)  ──Tailscale──►  tailnet
        │                                             │
        └──► public internet ──Tailscale Funnel──►    │
                                                      ▼
   Kubernetes on Talos ── Portainer (deploy UI)
                       ── local-path-provisioner (storage)
                       ── metrics-server (CPU/RAM)
                       ── Tailscale operator (private Ingress + public Funnel)
                       ── your apps (Deployments / Services / PVCs)
```

See [`docs/architecture.md`](docs/architecture.md) for the full picture and why CGNAT drives the design.

## Why these choices

| Goal | Chosen tool | Why |
|---|---|---|
| Remote access behind CGNAT | **Tailscale** | outbound WireGuard; works through any NAT |
| Public HTTPS without a domain | **Tailscale Funnel** | free `*.ts.net` URL, TLS included |
| On-demand app deployment | **Portainer CE (K8s)** | web UI over the Kubernetes API |
| Persistent volumes | **local-path-provisioner** | Talos has no built-in dynamic provisioner |
| Deploy from anywhere | **Tailscale operator** | per-app MagicDNS ingress + Funnel |

## Repository layout

```
.
├── README.md
├── talos/
│   ├── README.md                     # node prep, single-node taint, static IP
│   └── user-volume.patch.yaml        # UserVolumeConfig: data disk for storage
├── storage/
│   ├── README.md
│   ├── local-path-provisioner.yaml   # StorageClass + provisioner (path preconfigured)
│   └── test-pvc.yaml                 # validation pod/PVC
├── portainer/
│   ├── README.md                     # incl. the 5-minute setup-timeout fix
│   └── install.sh
├── metrics-server/
│   ├── README.md
│   └── install.sh
├── tailscale/
│   ├── README.md                     # ACL, OAuth, MagicDNS→HTTPS, install, expose
│   ├── acl-policy.json               # tailnet policy additions
│   ├── install-operator.sh
│   ├── portainer-ingress.yaml        # private ingress
│   └── demo-funnel-app.yaml          # public demo app
├── examples/
│   └── expose-an-app.md              # expose any Service private/public
└── docs/
    ├── architecture.md
    └── troubleshooting.md
```

## Prerequisites

- Talos Linux running on the node with a working Kubernetes cluster and `kubectl` access.
- Admin machine with: `kubectl`, `helm`, `talosctl` (matching the node's Talos version), `tailscale`.
- A Tailscale account with admin rights.
- A data disk on the node for persistent storage (USB/NVMe), or a reusable existing mount.

## Quickstart

Run in order. Replace the placeholders.

```bash
git clone <this-repo> && cd rock4c-talos-homelab
```

1. **Node prep** — verify tools/cluster, remove the control-plane taint, set a static IP.
   → [`talos/README.md`](talos/README.md)

2. **Storage** — create the backing volume and deploy local-path-provisioner (+ PSA fix).
   → [`storage/README.md`](storage/README.md)

3. **Portainer** — on-demand deploy UI (and skip its 5-minute timeout).
   → [`portainer/README.md`](portainer/README.md)

4. **metrics-server** — live CPU/RAM for Portainer and `kubectl top`.
   → [`metrics-server/README.md`](metrics-server/README.md)

5. **Tailscale** — ACL, OAuth client, MagicDNS→HTTPS, install operator, expose Portainer privately,
   expose a public demo app.
   → [`tailscale/README.md`](tailscale/README.md)

6. **Expose your own apps** — private or public, one Ingress.
   → [`examples/expose-an-app.md`](examples/expose-an-app.md)

## Placeholders used in this repo

| Placeholder | Meaning |
|---|---|
| `<NODE_IP>` | your node's LAN IP (e.g. `192.168.1.10`) |
| `<NODE_NAME>` | Kubernetes node name (e.g. `rock4-node`) |
| `<tailnet>` | your tailnet DNS name (e.g. `yak-bebop.ts.net`) |

Nothing in this repo contains credentials. The two secrets you create yourself (Tailscale OAuth
client and the Portainer admin password) stay out of version control — see `.gitignore`.

## Security notes

- Tailscale OAuth credentials and the Portainer admin password are **secrets** — never commit them.
- Keep **Portainer tailnet-only**; expose only apps you intend to be public.
- Never expose the Talos API, kubelet, etcd, or the Kubernetes API publicly.
- Funnel is TLS-only and bandwidth-throttled; use private Ingress for non-HTTP/TCP-UDP workloads.
- Single node = single point of failure. Back up etcd (`talosctl etcd snapshot`) and important PVCs.

## Credits

Built on [Talos Linux](https://www.talos.dev/), [Kubernetes](https://kubernetes.io/),
[Tailscale](https://tailscale.com/), [Portainer](https://www.portainer.io/), and
[local-path-provisioner](https://github.com/rancher/local-path-provisioner).
