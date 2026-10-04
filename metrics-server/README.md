# metrics-server

Gives the cluster a Metrics API so Portainer shows live CPU/RAM and `kubectl top` works.

```bash
./metrics-server/install.sh
kubectl top nodes
kubectl top pods -A
```

`--kubelet-insecure-tls` is required because Talos serves kubelet with self-signed certificates.
