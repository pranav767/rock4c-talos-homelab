# Architecture

## Layered stack

```
                        You (anywhere)
        ┌───────────────────────┴───────────────────────┐
        │ tailnet (private)                    public internet
        │                                            │
        │                                    Tailscale Funnel / relay
        │                                            │
        └───────────────► Tailscale ◄────────────────┘
                            │
   ┌────────────────────────┴──────────────────────────────────┐
   │  Kubernetes v1.3x  (the orchestrator everyone calls "k8s") │
   │   kube-apiserver · scheduler · controller-manager · etcd   │
   │   kubelet · containerd · CoreDNS · CNI                     │
   │                                                            │
   │   kube-system      metrics-server                          │
   │   local-path-storage  local-path-provisioner  (storage)    │
   │   portainer        Portainer CE              (deploy UI)   │
   │   tailscale        Tailscale operator        (networking)  │
   │   <your namespaces>  your apps (Deployments/Services/PVCs) │
   ├────────────────────────────────────────────────────────────┤
   │  Talos Linux  (immutable OS, API-managed, no SSH)          │
   ├────────────────────────────────────────────────────────────┤
   │  Rock 4 C+  (arm64 SBC, RAM, data disk)                    │
   └────────────────────────────────────────────────────────────┘
```

## What each piece is (and is not)

- **Talos Linux** — the OS. No shell/SSH; managed declaratively via the Talos API (`talosctl`).
- **Kubernetes** — already present on Talos. Schedules your containers as Pods. This *is* "k8s".
- **Portainer CE** — a Pod that calls the Kubernetes API. A convenience UI, **not** a Kubernetes
  replacement and **not** Docker. Optional: everything it does can be done with `kubectl`/`helm`.
- **local-path-provisioner** — storage plugin. Turns `PersistentVolumeClaim`s into real folders on
  the node's data disk. Talos ships no dynamic provisioner, so this is needed for stateful apps.
- **metrics-server** — provides the Metrics API (`kubectl top`, Portainer graphs).
- **Tailscale operator** — networking plugin. Creates ingress proxies so Services get a MagicDNS
  name, and optionally exposes them publicly via Funnel.
- **Tailscale Funnel** — public HTTPS ingress on a `*.ts.net` name, no domain, no port-forwarding.

## Traffic paths

**Private**
```
device on tailnet → MagicDNS name → tailscale IP → ingress proxy Pod → Kubernetes Service → app Pod
```

**Public**
```
internet → public DNS (Funnel relay IP) → Tailscale Funnel relay → encrypted tunnel to node
        → ingress proxy Pod (TLS terminated) → Kubernetes Service → app Pod
```
Public DNS records for Funnel names can take **up to ~10–20 minutes** to appear after enabling.

## Why CGNAT drives the design

Home ISPs commonly use **CGNAT** for IPv4: your router's WAN address is shared and inbound
port-forwarding silently does nothing. The fix is to avoid inbound connections entirely:

- Tailscale/WireGuard → **outbound** packet-switched tunnel.
- Tailscale Funnel → **outbound** connection to a relay that fronts public traffic.

No router changes, no static IP, no ISP call.

## Deploy flow (on-demand)

```
Browser → Portainer UI → kube-apiserver → scheduler → kubelet → containerd pulls image → Pod runs
```
