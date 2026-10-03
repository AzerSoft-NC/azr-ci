# Orchestrate AzerSoft apps from workspace sibling dirs.

root := justfile_directory()
ws := root / ".."
apps := ws / "src" / "azer-soft"
nginx := ws / "infra" / "azr-nginx"
pg := ws / "infra" / "azr-pg"
k3s := root / "k3s"

default:
    @just --list

# Create external Docker network (idempotent).
network:
    docker network inspect azersoft >/dev/null 2>&1 || docker network create azersoft

# Shared Postgres (Compose transition — infra/azr-pg).
up-pg: network
    cd "{{pg}}" && docker compose up -d

down-pg:
    cd "{{pg}}" && docker compose down

# k3d local cluster (Traefik disabled — nginx is the edge).
cluster-up:
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${HOME}/.local/bin:${PATH}"
    if k3d cluster list | grep -q '^azersoft-local'; then
      echo "cluster azersoft-local already exists"
    else
      k3d cluster create azersoft-local \
        --k3s-arg "--disable=traefik@server:0" \
        -p "8080:8080@server:0"
    fi
    kubectl config use-context k3d-azersoft-local

# Dev secrets for k3d (idempotent). Run after cluster-up, before deploy local.
secrets-local:
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${HOME}/.local/bin:${PATH}"
    kubectl config use-context k3d-azersoft-local
    kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace edge --dry-run=client -o yaml | kubectl apply -f -
    rand() { openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 24; }
    if kubectl -n platform get secret platform-postgres >/dev/null 2>&1; then
      echo "platform-postgres already exists"
    else
      kubectl -n platform create secret generic platform-postgres \
        --from-literal=postgres-password="$(rand)" \
        --from-literal=azr-www-password="$(rand)" \
        --from-literal=shipping-rates-password="$(rand)" \
        --from-literal=keycloak-password="$(rand)" \
        --from-literal=client-space-password="$(rand)"
    fi
    if kubectl -n platform get secret platform-garage >/dev/null 2>&1; then
      echo "platform-garage already exists"
    else
      kubectl -n platform create secret generic platform-garage \
        --from-literal=rpc-secret="$(openssl rand -hex 32)" \
        --from-literal=admin-token="$(rand)"
    fi
    if kubectl -n platform get secret platform-keycloak >/dev/null 2>&1; then
      echo "platform-keycloak already exists"
    else
      kubectl -n platform create secret generic platform-keycloak \
        --from-literal=admin-password="$(rand)"
    fi
    if kubectl -n platform get secret platform-mail >/dev/null 2>&1; then
      echo "platform-mail already exists"
    else
      kubectl -n platform create secret generic platform-mail \
        --from-literal=auth-token="$(rand)"
    fi

# Helm deploy platform + edge. Usage: just deploy local | just deploy droplet
deploy env="local":
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${HOME}/.local/bin:${PATH}"
    case "{{env}}" in
      local)
        CONTEXT=k3d-azersoft-local
        VF="{{k3s}}/values/local.yaml"
        VE="{{k3s}}/values/local-edge.yaml"
        ;;
      droplet)
        CONTEXT=azersoft-droplet
        VF="{{k3s}}/values/droplet.yaml"
        VE="{{k3s}}/values/droplet-edge.yaml"
        ;;
      *)
        echo "env must be local or droplet" >&2
        exit 1
        ;;
    esac
    kubectl config use-context "$CONTEXT"
    helm upgrade --install platform "{{k3s}}/charts/platform" \
      -n platform --create-namespace \
      -f "{{k3s}}/charts/platform/values.yaml" \
      -f "$VF"
    helm upgrade --install edge-nginx "{{k3s}}/charts/edge-nginx" \
      -n edge --create-namespace \
      -f "{{k3s}}/charts/edge-nginx/values.yaml" \
      -f "$VE"

down-cluster env="local":
    #!/usr/bin/env bash
    set -euo pipefail
    export PATH="${HOME}/.local/bin:${PATH}"
    if [[ "{{env}}" != "local" ]]; then
      echo "refusing to delete non-local cluster via just" >&2
      exit 1
    fi
    k3d cluster delete azersoft-local

# Dev mode: compose.yml + auto-loaded compose.override.yml per app.
up-dev: network
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> up-dev nginx"
    (cd "{{nginx}}" && docker compose up -d --build)
    for app in azr-www shopify-nc-shipping-rates; do
      echo "==> up-dev ${app}"
      (cd "{{apps}}/${app}" && docker compose up -d --build)
    done

# Prod-shaped locally: compose.yml + compose.prod.yml + compose.local.yml (still HTTP :8080).
up-local: network
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> up-local nginx"
    (cd "{{nginx}}" && docker compose -f compose.yml -f compose.prod.yml -f compose.local.yml up -d --build)
    for app in azr-www shopify-nc-shipping-rates; do
      echo "==> up-local ${app}"
      (cd "{{apps}}/${app}" && docker compose -f compose.yml -f compose.prod.yml -f compose.local.yml up -d --build)
    done

down:
    #!/usr/bin/env bash
    set -euo pipefail
    for app in shopify-nc-shipping-rates azr-www; do
      echo "==> down ${app}"
      (cd "{{apps}}/${app}" && docker compose down --remove-orphans 2>/dev/null || true)
    done
    echo "==> down nginx"
    (cd "{{nginx}}" && docker compose down --remove-orphans 2>/dev/null || true)

logs service="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "{{service}}" ]]; then
      if [[ "{{service}}" == "nginx" ]]; then
        cd "{{nginx}}" && docker compose logs -f --tail=100
      else
        cd "{{apps}}/{{service}}" && docker compose logs -f --tail=100
      fi
    else
      echo "=== nginx ==="
      (cd "{{nginx}}" && docker compose logs --tail=20) || true
      for app in azr-www shopify-nc-shipping-rates; do
        echo "=== ${app} ==="
        (cd "{{apps}}/${app}" && docker compose logs --tail=20) || true
      done
    fi
