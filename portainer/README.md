# Portainer CE (on-demand deploy UI)

[Portainer](https://www.portainer.io/) is a web UI that talks to the Kubernetes API. It is **not**
a replacement for Kubernetes — it lets you create/manage Deployments, Services, and Helm releases
by clicking instead of typing YAML.

## Install

```bash
NODE_NAME=<NODE_NAME> ./portainer/install.sh
```

Exposes Portainer via NodePort:

- HTTP: `http://<NODE_IP>:30777`
- HTTPS (self-signed): `https://<NODE_IP>:30779`

Persistence uses the default `local-path` StorageClass (see `../storage/`).

## The 5-minute initial-setup timeout (important)

Portainer CE **stops itself 5 minutes after first start** unless the admin account exists:

```
Your Portainer instance timed out for security purposes. To re-enable your Portainer instance, you will need to restart Portainer.
```

There is **no setting to extend this window**; it is a security feature. The correct fix is to
pre-create the admin account at startup with `--admin-password-file`:

```bash
# create a strong password without putting it in your shell history
PW="$(openssl rand -hex 16)"
printf '%s' "$PW" > /tmp/portainer-admin-password.txt
chmod 600 /tmp/portainer-admin-password.txt

kubectl -n portainer create secret generic portainer-admin-password \
  --from-literal=password="$PW" \
  --dry-run=client -o yaml | kubectl apply -f -
unset PW

helm upgrade --install -n portainer portainer portainer/portainer \
  --reuse-values \
  --set adminPassword.existingSecret=portainer-admin-password
```

Portainer now boots **already initialized**, so the timeout never triggers. Log in as user `admin`
with the password from the file, change it in the UI, then delete the secret/file.

## Do not expose it publicly

Keep Portainer tailnet-only (see `../tailscale/`). Only expose applications you intend to be public.
