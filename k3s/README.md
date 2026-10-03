# K3s / k3d charts

Charts/
  platform/     # postgres, valkey, garage (S3), keycloak, kong gateway, mail
  edge-nginx/   # TLS edge (ConfigMap vhosts; align with infra/azr-nginx on cutover)

values/
  local.yaml    # k3d
  droplet.yaml  # DigitalOcean K3s

## Secrets (not in git)

Create **before** `helm upgrade` (namespaces `platform` and `edge` must exist):

```bash
kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace edge --dry-run=client -o yaml | kubectl apply -f -

kubectl -n platform create secret generic platform-postgres \
  --from-literal=postgres-password=... \
  --from-literal=azr-www-password=... \
  --from-literal=shipping-rates-password=... \
  --from-literal=keycloak-password=...

kubectl -n platform create secret generic platform-garage \
  --from-literal=rpc-secret=... \
  --from-literal=admin-token=...

kubectl -n platform create secret generic platform-keycloak \
  --from-literal=admin-password=...

kubectl -n platform create secret generic platform-mail \
  --from-literal=auth-token=... \
  --from-literal=smtp-user=... \
  --from-literal=smtp-pass=...
# Optional multi-app map: --from-literal=app-tokens-json='{"appId":"token"}'
```

On k3d, `just secrets-local` generates dev secrets idempotently.

## Deploy

Fresh laptop: [docs/local-deploy.md](../../docs/local-deploy.md). From `ci/` (positional `env` argument — not `env=local`):

```bash
just cluster-up              # k3d, Traefik disabled, :8080 mapped
just secrets-local           # k3d dev secrets (optional if you created secrets manually)
just deploy local            # platform + edge (values/local*.yaml)
just deploy droplet          # requires kubecontext azersoft-droplet
just down-cluster local
```

Values:

| File | Chart |
|------|--------|
| `values/local.yaml` / `droplet.yaml` | platform |
| `values/local-edge.yaml` / `droplet-edge.yaml` | edge-nginx |

Local edge defaults disable app upstreams until app charts exist; `/healthz` on `http://localhost:8080` is enough for first smoke.

Compose Postgres for pre-K3s local work: `just up-pg` → `infra/azr-pg`.

## Mail

In-cluster HTTP API: `http://mail.platform.svc.cluster.local:3000` (`POST /v1/send`). ClusterIP only — no edge route.

Local (`values/local.yaml`): MailHog in the same namespace, `SMTP_HOST=mailhog`, `REQUIRE_AUTH=false`. UI: `kubectl -n platform port-forward svc/mailhog 8025:8025`.

Droplet: set `mail.smtp.host` (and port/secure) in `values/droplet.yaml` or a private override. `/ready` stays false until `SMTP_HOST` is non-empty. SMTP user/password live in Secret `platform-mail`, not in git.

Image: `ghcr.io/azersoft-nc/azr-mailer` from `infra/azr-mailer`. Before the first GHCR push, load a local build into k3d:

```bash
docker build -t ghcr.io/azersoft-nc/azr-mailer:latest infra/azr-mailer
k3d image import ghcr.io/azersoft-nc/azr-mailer:latest -c azersoft-local
```

## Valkey

In-cluster (RESP, Redis clients): `redis://valkey.platform.svc.cluster.local:6379`  
Cache only: the chart starts `valkey-server` with `--save ""` and `--appendonly no`. See [ADR 0005](../../context/adr/0005-valkey-cache.md).

## Garage (S3)

Cluster endpoint (path-style): `http://garage.platform.svc.cluster.local:3900`  
Region: `azersoft` (see `garage.s3Region` in chart values).

After the first deploy, create an app key and buckets (once per cluster):

```bash
kubectl -n platform exec deploy/garage -- garage key create azr-apps
kubectl -n platform exec deploy/garage -- garage bucket create apps
kubectl -n platform exec deploy/garage -- garage bucket allow \
  --read --write --owner apps azr-apps
```

Use the key id/secret from `garage key create` in app env (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT_URL`).
