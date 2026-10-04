# Talos node preparation

Assumes a Rock 4 C+ (arm64) already running Talos Linux with a working Kubernetes cluster.

## Tools (on your admin machine)

```bash
# talosctl must match the node's Talos version
talosctl version --nodes <NODE_IP>
# kubectl + helm to drive the cluster
kubectl version --client
helm version
```

## Verify cluster + node

```bash
kubectl get nodes -o wide
kubectl get pods -A
talosctl --nodes <NODE_IP> get disks
talosctl --nodes <NODE_IP> get blockdevices
talosctl --nodes <NODE_IP> read /proc/meminfo | grep -E 'MemTotal|MemAvailable'
```

## Single-node: allow workloads on the control plane

A single-node cluster usually keeps the control-plane `NoSchedule` taint. Remove it so Pods
schedule onto the node:

```bash
kubectl taint nodes <NODE_NAME> node-role.kubernetes.io/control-plane:NoSchedule-
```

Confirm there are no remaining taints:

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints}{"\n"}{end}'
```

## Strongly recommended: static IP / DHCP reservation

Give the node a fixed LAN IP (DHCP reservation on your router, or a static address) **before**
building on top of it. If DHCP hands out a different address after a reboot, your `kubeconfig`,
`talosconfig`, and any NodePort URLs break. Example static config lives in the Talos machine
config (`machine.network.interfaces`).

## Persistent storage backing volume

See [`talos/user-volume.patch.yaml`](user-volume.patch.yaml) and
[`../storage/README.md`](../storage/README.md).

```bash
talosctl --nodes <NODE_IP> patch mc --patch @talos/user-volume.patch.yaml
```
