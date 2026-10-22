# syntax=docker/dockerfile:1
# Image Caddy de la suite : contient les interfaces statiques de Tab et de Projets.
# Contexte de build : la racine d'atelier-deploy (les apps sont clonées dans apps/).

ARG PROTO=https

# ── Atelier Tab (interface web) ──────────────────────────────────────────────
FROM node:22-bookworm-slim AS tab
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /src
COPY apps/atelier-tab/package.json apps/atelier-tab/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY apps/atelier-tab/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN test -n "$ATELIER_DOMAIN" || (echo "ATELIER_DOMAIN manquant" && exit 1)
RUN VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_API_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build

# ── Atelier Projets (interface web ; l'API tourne dans son propre conteneur) ──
FROM node:24-bookworm-slim AS projets
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates python3 make g++ \
    && rm -rf /var/lib/apt/lists/*
ENV ELECTRON_SKIP_BINARY_DOWNLOAD=1 CI=1
WORKDIR /app
COPY apps/atelier_projets/package.json apps/atelier_projets/package-lock.json ./
COPY apps/atelier_projets/backend/package.json backend/
COPY apps/atelier_projets/frontend/package.json frontend/
COPY apps/atelier_projets/design-system/package.json design-system/
COPY apps/atelier_projets/desktop/package.json desktop/
RUN npm ci --include=dev --no-audit --no-fund
COPY apps/atelier_projets/ ./
ARG ATELIER_DOMAIN
ARG PROTO
RUN VITE_ATELIER_TAB_URL="$PROTO://tab.$ATELIER_DOMAIN" \
    VITE_ATELIER_VIZ_URL="$PROTO://viz.$ATELIER_DOMAIN" \
    VITE_ATELIER_PROJETS_URL="$PROTO://projets.$ATELIER_DOMAIN" \
    npm run build --workspace=@atelier/frontend

# ── Caddy ────────────────────────────────────────────────────────────────────
FROM caddy:2.10-alpine
COPY caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=tab /src/dist /srv/tab
COPY --from=projets /app/frontend/dist /srv/projets
