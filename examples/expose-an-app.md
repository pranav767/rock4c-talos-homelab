# Exposing an app (private or public)

Once the operator is installed, **any** Kubernetes Service can be exposed by creating a single
`Ingress` with `ingressClassName: tailscale`. The `tls.hosts[0]` value becomes the subdomain.

## 1. Deploy the app

```yaml
# app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels: { app: myapp }
  template:
    metadata:
      labels: { app: myapp }
    spec:
      containers:
        - name: myapp
          image: nginxdemos/hello:plain-text
          ports: [{ containerPort: 80 }]
          resources:
            requests: { cpu: 10m, memory: 16Mi }
            limits: { cpu: 200m, memory: 64Mi }
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: default
spec:
  selector: { app: myapp }
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f app.yaml
```

## 2a. Expose privately (tailnet only)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: default
spec:
  ingressClassName: tailscale
  defaultBackend:
    service: { name: myapp, port: { number: 80 } }
  tls:
    - hosts: [ myapp ]          # -> https://myapp.<tailnet>.ts.net
```

## 2b. Expose publicly (internet)

Identical, plus one annotation:

```yaml
metadata:
  name: myapp
  namespace: default
  annotations:
    tailscale.com/funnel: "true"
```

## 3. Confirm

```bash
kubectl -n default get ingress myapp      # wait for ADDRESS = myapp.<tailnet>.ts.net
curl -I https://myapp.<tailnet>.ts.net/
```

## Via the Portainer UI instead

1. Portainer → **Applications** → **Add application** (or **Manifests**) → paste the Deployment +
   Service YAML → Deploy.
2. Apply the Ingress YAML the same way (Portainer has a "Create from manifest" / YAML editor).
3. For public exposure, add the `tailscale.com/funnel: "true"` annotation.

## Storage for stateful apps

Add a PVC; the default `local-path` StorageClass provisions it automatically:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myapp-data
  namespace: default
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
```

## Removing an app

```bash
kubectl -n default delete ingress/myapp deploy/myapp svc/myapp pvc/myapp-data
```
