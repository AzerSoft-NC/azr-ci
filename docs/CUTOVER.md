# Droplet cutover: host nginx → nginx container (Compose)

**Scope:** transitional **Docker Compose** on the droplet — not the K3s/Helm cutover. For cluster migration, see [docs/plan-architecture-k3s.md](../../docs/plan-architecture-k3s.md).

Short maintenance window (~1–2 min).

## Before

- Existing certs in `/etc/letsencrypt`
- Apps running (`azr-www-web`, `nc-shipping-rates-*`)
- Bootstrap playbook run once (`ci/ansible/playbooks/bootstrap.yml`)

## Steps

```bash
# On droplet
sudo systemctl stop nginx
sudo systemctl disable nginx

cd /opt/azersoft/nginx
docker compose -f compose.prod.yml pull
docker compose -f compose.prod.yml up -d

curl -I https://azersoft.nc
curl -I https://apps.azersoft.nc/shopify-nc-shipping-rates/healthz
```

## After

Redeploy app stacks without public ports (`compose.prod.yml` — no `ports:` on app/db).

## Rollback

```bash
docker compose -f compose.prod.yml down
sudo systemctl enable nginx
sudo systemctl start nginx
```
