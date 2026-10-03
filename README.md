# AzerSoft infra

Shared platform for local dev and DigitalOcean droplet deploys.

> **Target direction:** same Helm charts on **k3d (local)** and **K3s (DigitalOcean droplet)** — shared Postgres/Valkey/Garage/Keycloak/API Gateway/Nginx/mail. See [plan d’action](../docs/plan-architecture-k3s.md) and [ADR 0001](../context/adr/0001-k3s-platform.md) / [ADR 0005](../context/adr/0005-valkey-cache.md). Compose + SSH deploy below remain the **current** path until cutover.

- **Terraform** — droplet, firewall, DNS (import existing resources; never recreate blindly)
- **Ansible** — one-shot bootstrap (Docker, UFW, deploy layout) → evolving to K3s bootstrap
- **GitHub Actions** — reusable `deploy-compose` workflow (build → GHCR → SSH compose pull/up) → evolving to Helm/kubectl
- **just** — local stack orchestration (`up-dev`, `up-local`, `down`, `logs`)

## Prerequisites

```bash
docker network create azersoft
# /etc/hosts
# 127.0.0.1 azersoft.nc www.azersoft.nc apps.azersoft.nc
```

Each app: `cp .env.example .env` and fill values (never commit secrets).

## Local

```bash
just up-dev      # dev overrides, nginx on :8080 HTTP
just up-local    # prod-shaped compose, still local ports
just down
just logs
```

Per-app only:

```bash
cd ../src/azer-soft/azr-www && docker compose up --build
```

## Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill DO token + droplet id
terraform init
terraform plan
terraform import digitalocean_droplet.main <droplet-id>   # first time only
terraform apply
```

## Ansible bootstrap

```bash
cd ansible
cp inventory.example inventory
cp group_vars/all.yml.example group_vars/all.yml
ansible-playbook -i inventory playbooks/bootstrap.yml
```

Run once after droplet exists. App deploys stay in GitHub Actions.

## Deploy (CI)

Each app repo calls `.github/workflows/deploy.yml` which uses the reusable workflow at the workspace root:

`AzerSoft-NC/azr-workspace/.github/workflows/deploy-compose.yml@main`

Required GitHub secrets (org or repo):

| Secret | Purpose |
|--------|---------|
| `DROPLET_HOST` | Droplet IP or hostname |
| `DROPLET_USER` | SSH user (e.g. deploy) |
| `DROPLET_SSH_KEY` | Private key for deploy user |
| `APP_ENV` | Full `.env` content for the app on the droplet |
| `GHCR_DEPLOY_TOKEN` | PAT or fine-grained token with `read:packages` for droplet `docker login` |

`GITHUB_TOKEN` pushes to GHCR when `packages: write` is granted.

## Layout on droplet

```
/opt/azersoft/
  nginx/
  azr-www/
  shopify-nc-shipping-rates/
```

Each directory holds `compose.prod.yml` and `.env` written by CI.
