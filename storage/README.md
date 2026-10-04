# Storage: local-path-provisioner

Talos ships **no dynamic storage provisioner**. This installs Rancher's
[local-path-provisioner](https://github.com/rancher/local-path-provisioner) and makes it the
default StorageClass, so any `PersistentVolumeClaim` gets a real directory on the node's data disk.

## 1. Create the backing volume

Two options.

**A. Dedicated user volume (recommended).** Apply `talos/user-volume.patch.yaml` (edit the
`diskSelector` first). Talos formats the selected disk and mounts it at
`/var/mnt/local-path-provisioner`:

```bash
talosctl --nodes <NODE_IP> patch mc --patch @talos/user-volume.patch.yaml
talosctl --nodes <NODE_IP> get volumestatus u-local-path-provisioner   # note the u- prefix
talosctl --nodes <NODE_IP> get mountstatus
```

**B. Reuse an existing mount.** If you already have a volume mounted (e.g. `/var/mnt/data`),
skip the patch and point the ConfigMap path in step 2 at that path instead.

> ⚠️ Talos **erases the disk** matched by `diskSelector`. Double-check the selector.

## 2. Deploy the provisioner

```bash
kubectl apply -f storage/local-path-provisioner.yaml
kubectl -n local-path-storage rollout status deploy/local-path-provisioner
kubectl get storageclass     # local-path (default)
```

The manifest here is upstream `v0.0.37` with two changes:

1. `StorageClass` annotated `storageclass.kubernetes.io/is-default-class: "true"`.
2. `nodePathMap` set to `/var/mnt/local-path-provisioner` (path from step 1).

## 3. Fix Pod Security Admission (required)

The provisioner launches a helper Pod that uses a `hostPath` volume. The default
`baseline` Pod Security level rejects `hostPath`, so provisioning fails with:

```
pods "helper-pod-create-..." is forbidden: violates PodSecurity "baseline:latest": hostPath volumes
```

Allow it on the provisioner's namespace:

```bash
kubectl label ns local-path-storage pod-security.kubernetes.io/enforce=privileged --overwrite
```

## 4. Verify

```bash
kubectl create namespace storage-test
kubectl apply -f storage/test-pvc.yaml
kubectl -n storage-test wait --for=condition=Ready pod/test-pod --timeout=120s
kubectl -n storage-test logs test-pod     # -> hello-from-local-path
kubectl delete namespace storage-test
```

## Notes

- `volumeBindingMode: WaitForFirstConsumer` means a PVC stays `Pending` until a Pod uses it. That is expected.
- Single node = no replication. Back up important data; do not treat this as HA.
- Data lives under `/var/mnt/local-path-provisioner`. Deleting a PVC with `reclaimPolicy: Delete` removes the data.
